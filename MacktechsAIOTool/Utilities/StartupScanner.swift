//
//  StartupScanner.swift
//  Macktechs AIO Tool
//
//  Read-only scan of LaunchAgents, LaunchDaemons, Login Items.
//

import Foundation
import AppKit

struct StartupItem: Identifiable, Codable, Hashable {
    var id: UUID
    let name: String
    let path: String
    let developer: String?
    let isSigned: Bool
    let modified: Date?
    let notes: [String]
    let source: String

    init(id: UUID = UUID(), name: String, path: String, developer: String?, isSigned: Bool, modified: Date?, notes: [String], source: String) {
        self.id = id
        self.name = name
        self.path = path
        self.developer = developer
        self.isSigned = isSigned
        self.modified = modified
        self.notes = notes
        self.source = source
    }
}

enum StartupScanner {

    static func scanLaunchAgents(user: Bool) -> [StartupItem] {
        let dir = user
            ? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
            : URL(fileURLWithPath: "/Library/LaunchAgents")
        let source = user ? "User LaunchAgents" : "System LaunchAgents"
        return scanPlistDirectory(url: dir, source: source)
    }

    static func scanLaunchDaemons() -> [StartupItem] {
        let dir = URL(fileURLWithPath: "/Library/LaunchDaemons")
        return scanPlistDirectory(url: dir, source: "LaunchDaemons")
    }

    static func scanLoginItems() -> [StartupItem] {
        var items: [StartupItem] = []
        let script = "tell application \"System Events\" to get the name of every login item"
        guard let result = runAppleScript(script), !result.isEmpty else { return items }
        let names = result.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        for name in names where !name.isEmpty {
            let path = resolveLoginItemPath(name: name)
            let (developer, isSigned) = path != nil ? getSignatureInfo(for: path!) : (nil, false)
            items.append(StartupItem(
                name: name,
                path: path ?? "(unknown path)",
                developer: developer,
                isSigned: isSigned,
                modified: nil,
                notes: path == nil ? ["path not resolved"] : [],
                source: "Login Items"
            ))
        }
        return items
    }

    static func getSignatureInfo(for path: String) -> (developer: String?, isSigned: Bool) {
        let url = URL(fileURLWithPath: path)
        guard url.isFileURL else { return (nil, false) }
        return getSignatureInfo(for: url)
    }

    static func getSignatureInfo(for url: URL) -> (developer: String?, isSigned: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dv", "--verbose=2", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8) ?? ""
            let signed = process.terminationStatus == 0
            var developer: String?
            for line in out.components(separatedBy: "\n") {
                if line.contains("Authority=Developer ID Application:") {
                    let parts = line.split(separator: "=", maxSplits: 1)
                    if parts.count == 2 {
                        developer = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    }
                    break
                }
                if line.contains("Authority=Apple ") {
                    developer = "Apple"
                    break
                }
            }
            return (developer, signed)
        } catch {
            return (nil, false)
        }
    }

    private static func scanPlistDirectory(url: URL, source: String) -> [StartupItem] {
        var items: [StartupItem] = []
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else { return items }
        for fileURL in contents where fileURL.pathExtension == "plist" {
            let (name, path, modified, notes) = parseLaunchPlist(fileURL)
            let (developer, isSigned) = path != nil ? getSignatureInfo(for: path!) : (nil, false)
            items.append(StartupItem(
                name: name,
                path: path ?? fileURL.path,
                developer: developer,
                isSigned: isSigned,
                modified: modified,
                notes: notes,
                source: source
            ))
        }
        return items
    }

    private static func parseLaunchPlist(_ plistURL: URL) -> (name: String, executablePath: String?, modified: Date?, notes: [String]) {
        let name = plistURL.deletingPathExtension().lastPathComponent
        var notes: [String] = []
        var modDate: Date?
        if let attrs = try? FileManager.default.attributesOfItem(atPath: plistURL.path),
           let d = attrs[.modificationDate] as? Date {
            modDate = d
        }
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return (name, nil, modDate, ["unreadable plist"])
        }
        var path: String?
        if let p = plist["Program"] as? String {
            path = p
        } else if let p = plist["ProgramArguments"] as? [String], let first = p.first {
            path = first
        }
        if let p = path {
            var expanded = (p as NSString).expandingTildeInPath
            if (expanded as NSString).isAbsolutePath == false, let workDir = plist["WorkingDirectory"] as? String {
                expanded = (workDir as NSString).appendingPathComponent(p)
            }
            expanded = (expanded as NSString).expandingTildeInPath
            if !FileManager.default.fileExists(atPath: expanded) {
                notes.append("missing executable")
            }
            path = expanded
        } else {
            notes.append("no executable in plist")
        }
        return (name, path, modDate, notes)
    }

    private static func resolveLoginItemPath(name: String) -> String? {
        let escaped = name
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "System Events"
            set loginItems to login items
            repeat with itemRef in loginItems
                if name of itemRef is "\(escaped)" then
                    if kind of itemRef is file then
                        return path of itemRef as text
                    end if
                    exit repeat
                end if
            end repeat
        end tell
        """
        return runAppleScript(script)
    }

    private static func runAppleScript(_ script: String) -> String? {
        var error: NSDictionary?
        guard let scriptObj = NSAppleScript(source: script) else { return nil }
        let output = scriptObj.executeAndReturnError(&error)
        if let err = error { return nil }
        return output.stringValue?.trimmingCharacters(in: .whitespaces)
    }
}
