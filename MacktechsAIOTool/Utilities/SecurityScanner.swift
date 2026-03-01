//
//  SecurityScanner.swift
//  Macktechs AIO Mac Tool
//
//  Read-only security scan: profiles, SIP, Gatekeeper, XProtect, MRT, hosts, etc.
//

import Foundation

struct SecurityFinding: Identifiable, Codable, Hashable {
    var id: UUID
    let category: String
    let title: String
    let detail: String
    let severity: String

    init(id: UUID = UUID(), category: String, title: String, detail: String, severity: String) {
        self.id = id
        self.category = category
        self.title = title
        self.detail = detail
        self.severity = severity
    }
}

enum SecurityScanner {

    private static let suspiciousPatterns = [
        "mackeeper", "mackeepr", "advancedmaccleaner", "searchmarquis",
        "search baron", "searchbaron", "chilltab", "weknow", "anysearch", "mybrowserhelper",
    ]

    static func scan(startupItems: [StartupItem]) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []
        findings += scanConfigurationProfiles()
        findings += scanSIP()
        findings += scanGatekeeper()
        findings += scanXProtect()
        findings += scanMRT()
        findings += scanHosts()
        findings += scanSuspiciousStartupItems(startupItems)
        return findings.sorted { s1, s2 in
            let order = ["Critical", "Warning", "Info"]
            let i1 = order.firstIndex(of: s1.severity) ?? 3
            let i2 = order.firstIndex(of: s2.severity) ?? 3
            return i1 < i2
        }
    }

    private static func run(_ launchPath: String, args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private static func scanConfigurationProfiles() -> [SecurityFinding] {
        var list: [SecurityFinding] = []
        guard let out = run("/usr/bin/profiles", args: ["show", "-output", "stdout-xml"]) ?? run("/usr/bin/profiles", args: ["-P"]) else {
            list.append(SecurityFinding(category: "Profiles", title: "Configuration profiles", detail: "Could not read profiles.", severity: "Info"))
            return list
        }
        if out.contains("<key>PayloadContent</key>") || out.contains("profile") {
            list.append(SecurityFinding(category: "Profiles", title: "Configuration profiles", detail: out.prefix(500).description, severity: "Info"))
        } else {
            list.append(SecurityFinding(category: "Profiles", title: "Configuration profiles", detail: out, severity: "Info"))
        }
        if out.lowercased().contains("mdm") {
            list.append(SecurityFinding(category: "Profiles", title: "MDM enrollment", detail: "MDM-related profile(s) present.", severity: "Info"))
        }
        return list
    }

    private static func scanSIP() -> [SecurityFinding] {
        guard let out = run("/usr/bin/csrutil", args: ["status"]) else {
            return [SecurityFinding(category: "SIP", title: "System Integrity Protection", detail: "Could not read status.", severity: "Info")]
        }
        let enabled = out.lowercased().contains("enabled")
        return [SecurityFinding(category: "SIP", title: "System Integrity Protection", detail: out.trimmingCharacters(in: .whitespacesAndNewlines), severity: enabled ? "Info" : "Warning")]
    }

    private static func scanGatekeeper() -> [SecurityFinding] {
        guard let out = run("/usr/sbin/spctl", args: ["--status"]) else {
            return [SecurityFinding(category: "Gatekeeper", title: "Gatekeeper", detail: "Could not read status.", severity: "Info")]
        }
        return [SecurityFinding(category: "Gatekeeper", title: "Gatekeeper", detail: out.trimmingCharacters(in: .whitespacesAndNewlines), severity: "Info")]
    }

    private static func scanXProtect() -> [SecurityFinding] {
        let plist = "/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist"
        guard FileManager.default.fileExists(atPath: plist),
              let data = try? Data(contentsOf: URL(fileURLWithPath: plist)),
              let plistObj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let version = plistObj["CFBundleShortVersionString"] as? String ?? plistObj["CFBundleVersion"] as? String else {
            return [SecurityFinding(category: "XProtect", title: "XProtect", detail: "Version unknown.", severity: "Info")]
        }
        return [SecurityFinding(category: "XProtect", title: "XProtect version", detail: version, severity: "Info")]
    }

    private static func scanMRT() -> [SecurityFinding] {
        let mrt = "/Library/Apple/System/Library/CoreServices/MRT.app/Contents/Info.plist"
        guard FileManager.default.fileExists(atPath: mrt),
              let data = try? Data(contentsOf: URL(fileURLWithPath: mrt)),
              let plistObj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let version = plistObj["CFBundleShortVersionString"] as? String ?? plistObj["CFBundleVersion"] as? String else {
            return [SecurityFinding(category: "MRT", title: "MRT", detail: "Version unknown.", severity: "Info")]
        }
        return [SecurityFinding(category: "MRT", title: "MRT version", detail: version, severity: "Info")]
    }

    private static func scanHosts() -> [SecurityFinding] {
        let path = "/etc/hosts"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return [SecurityFinding(category: "Hosts", title: "/etc/hosts", detail: "Could not read.", severity: "Info")]
        }
        let lower = content.lowercased()
        var severity = "Info"
        for pattern in suspiciousPatterns {
            if lower.contains(pattern) {
                severity = "Warning"
                break
            }
        }
        return [SecurityFinding(category: "Hosts", title: "/etc/hosts", detail: content, severity: severity)]
    }

    private static func scanSuspiciousStartupItems(_ items: [StartupItem]) -> [SecurityFinding] {
        var list: [SecurityFinding] = []
        for item in items {
            let combined = (item.name + " " + item.path).lowercased()
            for pattern in suspiciousPatterns {
                if combined.contains(pattern) {
                    list.append(SecurityFinding(
                        category: "Startup",
                        title: "Suspicious startup item",
                        detail: "\(item.name) at \(item.path)",
                        severity: "Warning"
                    ))
                    break
                }
            }
            if !item.isSigned && !item.notes.isEmpty {
                list.append(SecurityFinding(
                    category: "Startup",
                    title: "Unsigned startup item",
                    detail: "\(item.name) at \(item.path)",
                    severity: "Info"
                ))
            }
        }
        return list
    }
}
