//
//  BrowserHealthScanner.swift
//  Macktechs AIO Mac Tool
//
//  Read-only browser health scan. Reimplements browser_health_check.sh in Swift.
//

import Foundation

struct BrowserHealthScanner {

    static func runFullScan() async -> BrowserHealthReport {
        var suspiciousFindings: [SuspiciousFinding] = []

        let macVersion = runCommand("/usr/bin/sw_vers", ["-productVersion"]).trimmingCharacters(in: .whitespacesAndNewlines)
        let arch = runCommand("/usr/bin/uname", ["-m"]).trimmingCharacters(in: .whitespacesAndNewlines)

        let hosts = scanHosts(findings: &suspiciousFindings)
        let dns = scanDNS()
        let proxies = scanProxies(findings: &suspiciousFindings)
        let launchEntries = scanLaunchEntries(findings: &suspiciousFindings)
        let loginItems = scanLoginItems(findings: &suspiciousFindings)
        let chrome = scanChrome(findings: &suspiciousFindings)
        let firefox = scanFirefox(findings: &suspiciousFindings)
        let safari = scanSafari(findings: &suspiciousFindings)
        let browserProcesses = scanBrowserProcesses(findings: &suspiciousFindings)

        return BrowserHealthReport(
            generatedAt: Date(),
            macOSVersion: macVersion,
            architecture: arch,
            hosts: hosts,
            dns: dns,
            proxies: proxies,
            launchEntries: launchEntries,
            loginItems: loginItems,
            chrome: chrome,
            firefox: firefox,
            safari: safari,
            browserProcesses: browserProcesses,
            suspiciousSummary: suspiciousFindings
        )
    }

    // MARK: - Helpers

    static func runCommand(_ launchPath: String, _ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    // MARK: - Hosts

    static func scanHosts(findings: inout [SuspiciousFinding]) -> HostsCheckResult {
        let path = "/etc/hosts"
        let contents: String
        if FileManager.default.isReadableFile(atPath: path),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let s = String(data: data, encoding: .utf8) {
            contents = s
        } else {
            contents = "(Cannot read /etc/hosts)"
        }
        let suspicious = SuspiciousPatternEngine.isSuspicious(contents)
        if suspicious {
            findings.append(SuspiciousFinding(category: "Hosts", description: "Suspicious pattern found in /etc/hosts"))
        }
        return HostsCheckResult(contents: contents, suspicious: suspicious)
    }

    // MARK: - DNS

    static func scanDNS() -> [DNSCheckResult] {
        let out = runCommand("/usr/sbin/networksetup", ["-getdnsservers", "Wi-Fi"])
        let servers = out.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return [DNSCheckResult(serviceName: "Wi-Fi", servers: servers)]
    }

    // MARK: - Proxies

    static func scanProxies(findings: inout [SuspiciousFinding]) -> [ProxyCheckResult] {
        let web = runCommand("/usr/sbin/networksetup", ["-getwebproxy", "Wi-Fi"])
        let secure = runCommand("/usr/sbin/networksetup", ["-getsecurewebproxy", "Wi-Fi"])
        let combined = web + " " + secure
        let suspicious = SuspiciousPatternEngine.isSuspicious(combined)
        if suspicious {
            findings.append(SuspiciousFinding(category: "Wi-Fi Proxy", description: "Suspicious pattern in proxy settings"))
        }
        return [ProxyCheckResult(
            serviceName: "Wi-Fi",
            webProxy: web.isEmpty ? nil : web,
            secureProxy: secure.isEmpty ? nil : secure,
            suspicious: suspicious
        )]
    }

    // MARK: - LaunchAgents / LaunchDaemons

    static func scanLaunchEntries(findings: inout [SuspiciousFinding]) -> [LaunchEntry] {
        var entries: [LaunchEntry] = []
        let dirs: [(String, String)] = [
            (FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents").path, "User LaunchAgent"),
            ("/Library/LaunchAgents", "System LaunchAgent"),
            ("/Library/LaunchDaemons", "System LaunchDaemon"),
        ]
        for (path, kind) in dirs {
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: path) else { continue }
            for name in names.sorted() {
                let fullPath = (path as NSString).appendingPathComponent(name)
                var line = name
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? Int64,
                   let mod = attrs[.modificationDate] as? Date {
                    line = "\(name)  \(size)  \(mod)"
                }
                let suspicious = SuspiciousPatternEngine.isSuspicious(fullPath + " " + name)
                if suspicious {
                    findings.append(SuspiciousFinding(category: kind, description: "Suspicious pattern in \(name)"))
                }
                entries.append(LaunchEntry(kind: kind, path: fullPath, line: line, suspicious: suspicious))
            }
        }
        return entries
    }

    // MARK: - Login Items

    static func scanLoginItems(findings: inout [SuspiciousFinding]) -> LoginItemsResult {
        let out = runCommand("/usr/bin/osascript", ["-e", "tell application \"System Events\" to get the name of every login item"])
        let items = out.components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let combined = items.joined(separator: " ")
        let suspicious = SuspiciousPatternEngine.isSuspicious(combined)
        if suspicious {
            findings.append(SuspiciousFinding(category: "Login Items", description: "Suspicious pattern in login item names"))
        }
        return LoginItemsResult(items: items, suspicious: suspicious)
    }

    // MARK: - Chrome

    static func scanChrome(findings: inout [SuspiciousFinding]) -> ChromeCheckResult {
        let chromeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome")
        guard FileManager.default.fileExists(atPath: chromeDir.path) else {
            return ChromeCheckResult(installed: false, profiles: [], extensions: [], managedPreferences: nil)
        }

        var profiles: [String] = []
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: chromeDir.path) {
            for name in contents {
                let full = (chromeDir.path as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue {
                    if name == "Default" || name.hasPrefix("Profile ") {
                        profiles.append(full)
                    }
                }
            }
        }
        profiles.sort()

        var extensions: [ChromeExtensionInfo] = []
        let extDir = chromeDir.appendingPathComponent("Default/Extensions")
        if FileManager.default.fileExists(atPath: extDir.path),
           let extIds = try? FileManager.default.contentsOfDirectory(atPath: extDir.path) {
            for extId in extIds {
                let extPath = (extDir.path as NSString).appendingPathComponent(extId)
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: extPath, isDirectory: &isDir), isDir.boolValue else { continue }
                var name = "(no manifest)"
                if let sub = try? FileManager.default.contentsOfDirectory(atPath: extPath) {
                    for ver in sub {
                        let manifestPath = (extPath as NSString).appendingPathComponent("\(ver)/manifest.json")
                        if FileManager.default.fileExists(atPath: manifestPath),
                           let data = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let n = json["name"] as? String {
                                name = n
                                break
                            }
                            if let dict = json["name"] as? [String: String], let msg = dict["message"] {
                                name = msg
                                break
                            }
                        }
                    }
                }
                let suspicious = SuspiciousPatternEngine.isSuspicious(extId + " " + name)
                if suspicious {
                    findings.append(SuspiciousFinding(category: "Chrome Extensions", description: "Suspicious extension: \(name)"))
                }
                extensions.append(ChromeExtensionInfo(extensionID: extId, name: name, suspicious: suspicious))
            }
        }

        var managedPrefs: ChromeManagedPrefs?
        let plistPath = "/Library/Managed Preferences/com.google.Chrome.plist"
        if FileManager.default.fileExists(atPath: plistPath) {
            let raw = runCommand("/usr/bin/defaults", ["read", "/Library/Managed Preferences/com.google.Chrome"])
            let suspicious = SuspiciousPatternEngine.isSuspicious(raw)
            if suspicious {
                findings.append(SuspiciousFinding(category: "Chrome Managed Preferences", description: "Suspicious pattern in managed prefs"))
            }
            managedPrefs = ChromeManagedPrefs(raw: raw, suspicious: suspicious)
        }

        return ChromeCheckResult(
            installed: true,
            profiles: profiles,
            extensions: extensions,
            managedPreferences: managedPrefs
        )
    }

    // MARK: - Firefox

    static func scanFirefox(findings: inout [SuspiciousFinding]) -> FirefoxCheckResult {
        let ffDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Firefox/Profiles")
        guard FileManager.default.fileExists(atPath: ffDir.path) else {
            return FirefoxCheckResult(installed: false, profiles: [], globalPolicies: nil)
        }

        var profileExts: [FirefoxProfileExtensions] = []
        guard let profileDirs = try? FileManager.default.contentsOfDirectory(atPath: ffDir.path) else {
            return FirefoxCheckResult(installed: true, profiles: [], globalPolicies: nil)
        }

        for profileName in profileDirs.sorted() {
            let profilePath = (ffDir.path as NSString).appendingPathComponent(profileName)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: profilePath, isDirectory: &isDir), isDir.boolValue else { continue }
            var lines: [String] = []
            let extPath = (profilePath as NSString).appendingPathComponent("extensions")
            if FileManager.default.fileExists(atPath: extPath),
               let list = try? FileManager.default.contentsOfDirectory(atPath: extPath) {
                lines.append("Extensions: " + list.joined(separator: ", "))
            }
            let extJsonPath = (profilePath as NSString).appendingPathComponent("extensions.json")
            if FileManager.default.fileExists(atPath: extJsonPath),
               let data = try? Data(contentsOf: URL(fileURLWithPath: extJsonPath)),
               let str = String(data: data, encoding: .utf8) {
                lines.append("extensions.json: " + str.prefix(2000).description)
            }
            let raw = lines.joined(separator: "\n")
            let suspicious = SuspiciousPatternEngine.isSuspicious(raw)
            if suspicious {
                findings.append(SuspiciousFinding(category: "Firefox profile \(profileName)", description: "Suspicious pattern in extensions"))
            }
            profileExts.append(FirefoxProfileExtensions(profileName: profileName, rawExtensionsListing: raw.isEmpty ? "(none)" : raw, suspicious: suspicious))
        }

        var globalPolicies: FirefoxPolicies?
        let policiesPath = "/Library/Application Support/Mozilla/ManagedStorage/firefox/policies.json"
        if FileManager.default.fileExists(atPath: policiesPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: policiesPath)),
           let raw = String(data: data, encoding: .utf8) {
            let suspicious = SuspiciousPatternEngine.isSuspicious(raw)
            if suspicious {
                findings.append(SuspiciousFinding(category: "Firefox global policies", description: "Suspicious pattern in policies.json"))
            }
            globalPolicies = FirefoxPolicies(raw: raw, suspicious: suspicious)
        }

        return FirefoxCheckResult(installed: true, profiles: profileExts, globalPolicies: globalPolicies)
    }

    // MARK: - Safari

    static func scanSafari(findings: inout [SuspiciousFinding]) -> SafariCheckResult {
        let safariDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari")
        let extDir = safariDir.appendingPathComponent("Extensions")
        guard FileManager.default.fileExists(atPath: safariDir.path) else {
            return SafariCheckResult(installed: false, extensionsListing: nil, managedPreferences: nil, searchProvider: nil, homePage: nil, safariExtensionsOutput: nil, suspicious: false)
        }

        var extListing: String?
        if FileManager.default.fileExists(atPath: extDir.path),
           let list = try? FileManager.default.contentsOfDirectory(atPath: extDir.path) {
            extListing = list.joined(separator: "\n")
        }

        var extSuspicious = false
        if let e = extListing, SuspiciousPatternEngine.isSuspicious(e) {
            extSuspicious = true
            findings.append(SuspiciousFinding(category: "Safari Extensions", description: "Suspicious pattern in extensions folder"))
        }

        var managedPrefs: String?
        let safariPlist = "/Library/Managed Preferences/com.apple.Safari.plist"
        if FileManager.default.fileExists(atPath: safariPlist) {
            managedPrefs = runCommand("/usr/bin/defaults", ["read", "/Library/Managed Preferences/com.apple.Safari"])
            if let m = managedPrefs, SuspiciousPatternEngine.isSuspicious(m) {
                findings.append(SuspiciousFinding(category: "Safari Managed Preferences", description: "Suspicious pattern in managed prefs"))
            }
        }

        let searchProvider = runCommand("/usr/bin/defaults", ["read", "com.apple.Safari", "SearchProviderIdentifier"]).trimmingCharacters(in: .whitespacesAndNewlines)
        let homePage = runCommand("/usr/bin/defaults", ["read", "com.apple.Safari", "HomePage"]).trimmingCharacters(in: .whitespacesAndNewlines)
        let searchHomeCombined = "Search: \(searchProvider) Home: \(homePage)"
        var searchHomeSuspicious = SuspiciousPatternEngine.isSuspicious(searchHomeCombined)
        if searchHomeSuspicious {
            findings.append(SuspiciousFinding(category: "Safari search/homepage", description: "Suspicious pattern in search or homepage"))
        }

        let safariExtOutput = runCommand("/usr/sbin/systemextensionsctl", ["list"])
        let safariExtLines = safariExtOutput.components(separatedBy: "\n").filter { $0.lowercased().contains("safari") }.joined(separator: "\n")

        let anySuspicious = extSuspicious || searchHomeSuspicious || (managedPrefs.map { SuspiciousPatternEngine.isSuspicious($0) } ?? false)

        return SafariCheckResult(
            installed: true,
            extensionsListing: extListing ?? nil,
            managedPreferences: managedPrefs,
            searchProvider: searchProvider.isEmpty ? "(not set)" : searchProvider,
            homePage: homePage.isEmpty ? "(not set)" : homePage,
            safariExtensionsOutput: safariExtLines.isEmpty ? nil : safariExtLines,
            suspicious: anySuspicious
        )
    }

    // MARK: - Browser Processes

    static func scanBrowserProcesses(findings: inout [SuspiciousFinding]) -> [BrowserProcessInfo] {
        let out = runCommand("/bin/ps", ["aux"])
        let lines = out.components(separatedBy: "\n")
            .filter { $0.range(of: "Chrome|chrome|Firefox|firefox|Safari", options: .regularExpression) != nil }
            .filter { !$0.contains("egrep") && !$0.contains("grep") }
        let suspicious = SuspiciousPatternEngine.isSuspicious(out)
        if suspicious {
            findings.append(SuspiciousFinding(category: "Browser processes", description: "Suspicious pattern in process list"))
        }
        return lines.map { BrowserProcessInfo(line: $0, suspicious: suspicious) }
    }
}
