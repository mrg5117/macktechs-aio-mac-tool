//
//  BrowserHealthModels.swift
//  Macktechs AIO Mac Tool
//
//  Models for the browser health report (read-only). All Codable for JSON export.
//

import Foundation

struct HostsCheckResult: Codable {
    let contents: String
    let suspicious: Bool
}

struct DNSCheckResult: Codable {
    let serviceName: String
    let servers: [String]
}

struct ProxyCheckResult: Codable {
    let serviceName: String
    let webProxy: String?
    let secureProxy: String?
    let suspicious: Bool
}

struct LaunchEntry: Codable, Identifiable {
    var id: UUID
    let kind: String
    let path: String
    let line: String
    let suspicious: Bool

    enum CodingKeys: String, CodingKey { case kind, path, line, suspicious }
    init(id: UUID = UUID(), kind: String, path: String, line: String, suspicious: Bool) {
        self.id = id
        self.kind = kind
        self.path = path
        self.line = line
        self.suspicious = suspicious
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        kind = try c.decode(String.self, forKey: .kind)
        path = try c.decode(String.self, forKey: .path)
        line = try c.decode(String.self, forKey: .line)
        suspicious = try c.decode(Bool.self, forKey: .suspicious)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encode(path, forKey: .path)
        try c.encode(line, forKey: .line)
        try c.encode(suspicious, forKey: .suspicious)
    }
}

struct LoginItemsResult: Codable {
    let items: [String]
    let suspicious: Bool
}

struct ChromeExtensionInfo: Codable, Identifiable {
    var id: UUID
    let extensionID: String
    let name: String
    let suspicious: Bool

    enum CodingKeys: String, CodingKey { case extensionID, name, suspicious }
    init(id: UUID = UUID(), extensionID: String, name: String, suspicious: Bool) {
        self.id = id
        self.extensionID = extensionID
        self.name = name
        self.suspicious = suspicious
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        extensionID = try c.decode(String.self, forKey: .extensionID)
        name = try c.decode(String.self, forKey: .name)
        suspicious = try c.decode(Bool.self, forKey: .suspicious)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(extensionID, forKey: .extensionID)
        try c.encode(name, forKey: .name)
        try c.encode(suspicious, forKey: .suspicious)
    }
}

struct ChromeManagedPrefs: Codable {
    let raw: String
    let suspicious: Bool
}

struct ChromeCheckResult: Codable {
    let installed: Bool
    let profiles: [String]
    let extensions: [ChromeExtensionInfo]
    let managedPreferences: ChromeManagedPrefs?
}

struct FirefoxProfileExtensions: Codable, Identifiable {
    var id: UUID
    let profileName: String
    let rawExtensionsListing: String
    let suspicious: Bool

    enum CodingKeys: String, CodingKey { case profileName, rawExtensionsListing, suspicious }
    init(id: UUID = UUID(), profileName: String, rawExtensionsListing: String, suspicious: Bool) {
        self.id = id
        self.profileName = profileName
        self.rawExtensionsListing = rawExtensionsListing
        self.suspicious = suspicious
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        profileName = try c.decode(String.self, forKey: .profileName)
        rawExtensionsListing = try c.decode(String.self, forKey: .rawExtensionsListing)
        suspicious = try c.decode(Bool.self, forKey: .suspicious)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(profileName, forKey: .profileName)
        try c.encode(rawExtensionsListing, forKey: .rawExtensionsListing)
        try c.encode(suspicious, forKey: .suspicious)
    }
}

struct FirefoxPolicies: Codable {
    let raw: String
    let suspicious: Bool
}

struct FirefoxCheckResult: Codable {
    let installed: Bool
    let profiles: [FirefoxProfileExtensions]
    let globalPolicies: FirefoxPolicies?
}

struct SafariCheckResult: Codable {
    let installed: Bool
    let extensionsListing: String?
    let managedPreferences: String?
    let searchProvider: String?
    let homePage: String?
    let safariExtensionsOutput: String?
    let suspicious: Bool
}

struct BrowserProcessInfo: Codable, Identifiable {
    var id: UUID
    let line: String
    let suspicious: Bool

    enum CodingKeys: String, CodingKey { case line, suspicious }
    init(id: UUID = UUID(), line: String, suspicious: Bool) {
        self.id = id
        self.line = line
        self.suspicious = suspicious
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        line = try c.decode(String.self, forKey: .line)
        suspicious = try c.decode(Bool.self, forKey: .suspicious)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(line, forKey: .line)
        try c.encode(suspicious, forKey: .suspicious)
    }
}

struct SuspiciousFinding: Codable, Identifiable {
    var id: UUID
    let category: String
    let description: String

    enum CodingKeys: String, CodingKey { case category, description }
    init(id: UUID = UUID(), category: String, description: String) {
        self.id = id
        self.category = category
        self.description = description
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        category = try c.decode(String.self, forKey: .category)
        description = try c.decode(String.self, forKey: .description)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(category, forKey: .category)
        try c.encode(description, forKey: .description)
    }
}

struct BrowserHealthReport: Codable {
    let generatedAt: Date
    let macOSVersion: String
    let architecture: String
    let hosts: HostsCheckResult
    let dns: [DNSCheckResult]
    let proxies: [ProxyCheckResult]
    let launchEntries: [LaunchEntry]
    let loginItems: LoginItemsResult
    let chrome: ChromeCheckResult
    let firefox: FirefoxCheckResult
    let safari: SafariCheckResult
    let browserProcesses: [BrowserProcessInfo]
    let suspiciousSummary: [SuspiciousFinding]
}
