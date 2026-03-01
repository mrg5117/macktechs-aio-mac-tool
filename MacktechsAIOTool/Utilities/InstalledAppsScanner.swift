//
//  InstalledAppsScanner.swift
//  Macktechs AIO Mac Tool
//
//  Read-only scan of /Applications, /Applications/Utilities, ~/Applications.
//

import Foundation
import AppKit

struct InstalledApp: Identifiable, Codable, Hashable {
    var id: UUID
    let name: String
    let version: String?
    let bundleID: String?
    let developer: String?
    let isSigned: Bool
    let architecture: String
    let sizeMB: Double
    let lastOpened: Date?
    let path: String

    init(id: UUID = UUID(), name: String, version: String?, bundleID: String?, developer: String?, isSigned: Bool, architecture: String, sizeMB: Double, lastOpened: Date?, path: String) {
        self.id = id
        self.name = name
        self.version = version
        self.bundleID = bundleID
        self.developer = developer
        self.isSigned = isSigned
        self.architecture = architecture
        self.sizeMB = sizeMB
        self.lastOpened = lastOpened
        self.path = path
    }
}

enum InstalledAppsScanner {

    static let applicationURLs: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/Applications/Utilities"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
    ]

    static func scan() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        for baseURL in applicationURLs {
            guard let contents = try? FileManager.default.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else { continue }
            for url in contents {
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                      url.pathExtension == "app" else { continue }
                if let app = info(for: url) {
                    apps.append(app)
                }
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func info(for bundleURL: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: bundleURL) else { return nil }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundleURL.deletingPathExtension().lastPathComponent
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let bundleID = bundle.bundleIdentifier
        let path = bundleURL.path
        let (developer, isSigned) = StartupScanner.getSignatureInfo(for: bundleURL)
        let arch = getArchitecture(bundle: bundle) ?? "Unknown"
        let sizeMB = directorySizeMB(url: bundleURL)
        let lastOpened = getLastOpened(url: bundleURL)
        return InstalledApp(
            name: name,
            version: version,
            bundleID: bundleID,
            developer: developer,
            isSigned: isSigned,
            architecture: arch,
            sizeMB: sizeMB,
            lastOpened: lastOpened,
            path: path
        )
    }

    private static func getArchitecture(bundle: Bundle) -> String? {
        guard let execURL = bundle.executableURL else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        process.arguments = ["-info", execURL.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        if out.contains("arm64") && out.contains("x86_64") { return "Universal" }
        if out.contains("arm64") { return "ARM" }
        if out.contains("x86_64") { return "Intel" }
        return nil
    }

    private static func directorySizeMB(url: URL) -> Double {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            total += Int64(size)
        }
        return Double(total) / (1024 * 1024)
    }

    private static func getLastOpened(url: URL) -> Date? {
        var resource = URLResourceValues()
        resource.contentAccessDate = nil
        guard let values = try? url.resourceValues(forKeys: [.contentAccessDateKey]) else { return nil }
        return values.contentAccessDate
    }
}
