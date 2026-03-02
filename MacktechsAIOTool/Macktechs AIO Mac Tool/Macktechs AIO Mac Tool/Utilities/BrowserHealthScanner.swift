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
            macOSVersion: macVersion.isEmpty ? "Unknown" : macVersion,
            architecture: arch.isEmpty ? "Unknown" : arch,
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

    private static func listNetworkServices() -> [String] {
        let raw = runCommand("/usr/sbin/networksetup", ["-listallnetworkservices"])
        return raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("An asterisk") && !$0.hasPrefix("*") }
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

    /// Phase 2.5: scan DNS for ALL active network services, not just Wi-Fi.
    static func scanDNS() -> [DNSCheckResult] {
        let services = listNetworkServices()
        var results: [DNSCheckResult] = []

        for service in services {
            let out = runCommand("/usr/sbin/networksetup", ["-getdnsservers", service])
            let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty || trimmed.contains("There aren't any DNS Servers set") {
                results.append(DNSCheckResult(serviceName: service, servers: []))
            } else {
                let servers = trimmed
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                results.append(DNSCheckResult(serviceName: service, servers: servers))
            }
        }

        return results
    }

    // MARK: - Proxies

    /// Phase 2.5: scan proxies for ALL active network services.
    static func scanProxies(findings: inout [SuspiciousFinding]) -> [ProxyCheckResult] {
        let services = listNetworkServices()
        var results: [ProxyCheckResult] = []

        for service in services {
            let web = runCommand("/usr/sbin/networksetup", ["-getwebproxy", service])
            let secure = runCommand("/usr/sbin/networksetup", ["-getsecurewebproxy", service])
            let combined = web + "\n" + secure

            let suspicious = SuspiciousPatternEngine.isSuspicious(combined)
            if suspicious {
                findings.append(SuspiciousFinding(category: "\(service) Proxy", description: "Suspicious pattern in proxy settings for \(service)"))
            }

            results.append(
                ProxyCheckResult(
                    serviceName: service,
                    webProxy: web.isEmpty ? nil : web,
                    secureProxy: secure.isEmpty ? nil : secure,
                    suspicious: suspicious
                )
            )
        }

        return results
    }

    // MARK: - LaunchAgents / LaunchDaemons

    static func scanLaunchEntries(findings: inout [SuspiciousFinding]) -> [LaunchEntry] {
        var entries: [LaunchEntry] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dirs: [(String, String)] = [
            (home.appendingPathComponent("Library/LaunchAgents").path, "User LaunchAgent"),
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
        let items = out.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.localizedCaseInsensitiveContains("System Events got an error") }
        let combined = items.joined(separator: " ")
        let suspicious = SuspiciousPatternEngine.isSuspicious(combined)
        if suspicious {
            findings.append(SuspiciousFinding(category: "Login Items", description: "Suspicious pattern in login item names"))
        }
        return LoginItemsResult(items: items, suspicious: suspicious)
    }

    // MARK: - Chrome

    /// Phase 2.5:
    /// - more robust "installed" detection
    /// - inspect Default/Preferences for homepage, startup URLs, search provider
    static func scanChrome(findings: inout [SuspiciousFinding]) -> ChromeCheckResult {
        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser
        let chromeSupportDir = homeDir.appendingPathComponent("Library/Application Support/Google/Chrome")

        var isDir: ObjCBool = false
        let supportExists = fm.fileExists(atPath: chromeSupportDir.path, isDirectory: &isDir) && isDir.boolValue

        let chromeAppCandidates = [
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            (homeDir.path as NSString).appendingPathComponent("Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
        ]
        let chromeBinary = chromeAppCandidates.first { fm.fileExists(atPath: $0) }

        let installed = supportExists || (chromeBinary != nil)
        guard installed else {
            return ChromeCheckResult(installed: false, profiles: [], extensions: [], managedPreferences: nil)
        }

        // Profiles (unchanged).
        var profiles: [String] = []
        if supportExists,
           let contents = try? fm.contentsOfDirectory(atPath: chromeSupportDir.path) {
            for name in contents {
                let full = (chromeSupportDir.path as NSString).appendingPathComponent(name)
                var isProfileDir: ObjCBool = false
                if fm.fileExists(atPath: full, isDirectory: &isProfileDir), isProfileDir.boolValue {
                    if name == "Default" || name.hasPrefix("Profile ") {
                        profiles.append(full)
                    }
                }
            }
        }
        profiles.sort()

        var extensions: [ChromeExtensionInfo] = []
        let extDir = chromeSupportDir.appendingPathComponent("Default/Extensions")
        if fm.fileExists(atPath: extDir.path),
           let extIds = try? fm.contentsOfDirectory(atPath: extDir.path) {
            for extId in extIds {
                let extPath = (extDir.path as NSString).appendingPathComponent(extId)
                var isExtDir: ObjCBool = false
                guard fm.fileExists(atPath: extPath, isDirectory: &isExtDir), isExtDir.boolValue else { continue }
                var name = "(no manifest)"
                if let sub = try? fm.contentsOfDirectory(atPath: extPath) {
                    for ver in sub {
                        let manifestPath = (extPath as NSString).appendingPathComponent("\(ver)/manifest.json")
                        if fm.fileExists(atPath: manifestPath),
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

        // Managed prefs (unchanged).
        var managedPrefs: ChromeManagedPrefs?
        let plistPath = "/Library/Managed Preferences/com.google.Chrome.plist"
        if fm.fileExists(atPath: plistPath) {
            let raw = runCommand("/usr/bin/defaults", ["read", "/Library/Managed Preferences/com.google.Chrome"])
            let suspicious = SuspiciousPatternEngine.isSuspicious(raw)
            if suspicious {
                findings.append(SuspiciousFinding(category: "Chrome Managed Preferences", description: "Suspicious pattern in managed prefs"))
            }
            managedPrefs = ChromeManagedPrefs(raw: raw, suspicious: suspicious)
        }

        // Phase 2.5: inspect Default/Preferences for homepage, startup URLs, search provider.
        let preferencesPath = chromeSupportDir.appendingPathComponent("Default/Preferences").path
        if fm.fileExists(atPath: preferencesPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: preferencesPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            var interestingStrings: [String] = []

            if let homepage = json["homepage"] as? String {
                interestingStrings.append("homepage=\(homepage)")
            }
            if let session = json["session"] as? [String: Any] {
                if let urls = session["startup_urls"] as? [String] {
                    interestingStrings.append("startup_urls=" + urls.joined(separator: ","))
                }
            }
            if let dsp = json["default_search_provider"] as? [String: Any] {
                if let name = dsp["name"] as? String {
                    interestingStrings.append("search_name=\(name)")
                }
                if let url = dsp["search_url"] as? String {
                    interestingStrings.append("search_url=\(url)")
                }
            }

            let combined = interestingStrings.joined(separator: " | ")
            if !combined.isEmpty && SuspiciousPatternEngine.isSuspicious(combined) {
                findings.append(SuspiciousFinding(category: "Chrome Startup/Search", description: "Suspicious Chrome homepage/startup/search configuration"))
            }
        }

        return ChromeCheckResult(
            installed: true,
            profiles: profiles,
            extensions: extensions,
            managedPreferences: managedPrefs
        )
    }

    // MARK: - Firefox

    /// Phase 2.5:
    /// - still scans extensions
    /// - also scans prefs.js/user.js for proxy, homepage, search keys
    static func scanFirefox(findings: inout [SuspiciousFinding]) -> FirefoxCheckResult {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        // Check both app bundle and profiles directory
        let firefoxAppPaths = [
            "/Applications/Firefox.app",
            (home as NSString).appendingPathComponent("Applications/Firefox.app")
        ]
        let firefoxAppInstalled = firefoxAppPaths.contains { fm.fileExists(atPath: $0) }

        let profilesBase = (home as NSString)
            .appendingPathComponent("Library/Application Support/Firefox/Profiles")
        var isDir: ObjCBool = false
        let profilesExist = fm.fileExists(atPath: profilesBase, isDirectory: &isDir) && isDir.boolValue

        let installed = firefoxAppInstalled || profilesExist
        guard installed else {
            return FirefoxCheckResult(installed: false, profiles: [], globalPolicies: nil)
        }

        var profileExts: [FirefoxProfileExtensions] = []
        if profilesExist,
           let profileDirs = try? fm.contentsOfDirectory(atPath: profilesBase) {

            for profileName in profileDirs.sorted() {
                let profilePath = (profilesBase as NSString).appendingPathComponent(profileName)
                var isProfileDir: ObjCBool = false
                guard fm.fileExists(atPath: profilePath, isDirectory: &isProfileDir), isProfileDir.boolValue else { continue }

                var lines: [String] = []

                // Extensions directory
                let extPath = (profilePath as NSString).appendingPathComponent("extensions")
                if fm.fileExists(atPath: extPath),
                   let list = try? fm.contentsOfDirectory(atPath: extPath) {
                    lines.append("Extensions: " + list.joined(separator: ", "))
                }

                // extensions.json (trimmed)
                let extJsonPath = (profilePath as NSString).appendingPathComponent("extensions.json")
                if fm.fileExists(atPath: extJsonPath),
                   let data = try? Data(contentsOf: URL(fileURLWithPath: extJsonPath)),
                   let str = String(data: data, encoding: .utf8) {
                    lines.append("extensions.json: " + str.prefix(2000).description)
                }

                // Phase 2.5: prefs.js and user.js (proxy/home/search)
                let prefsCandidates = [
                    (profilePath as NSString).appendingPathComponent("prefs.js"),
                    (profilePath as NSString).appendingPathComponent("user.js")
                ]
                var prefsStrings: [String] = []
                for prefsPath in prefsCandidates {
                    if fm.fileExists(atPath: prefsPath),
                       let raw = try? String(contentsOfFile: prefsPath, encoding: .utf8) {
                        // Keep only lines about proxy/home/search so the report stays readable
                        let filtered = raw
                            .components(separatedBy: .newlines)
                            .filter {
                                $0.contains("network.proxy") ||
                                $0.contains("browser.startup.homepage") ||
                                $0.contains("browser.search")
                            }
                            .joined(separator: "\n")
                        if !filtered.isEmpty {
                            prefsStrings.append(filtered)
                        }
                    }
                }
                if !prefsStrings.isEmpty {
                    lines.append("prefs: " + prefsStrings.joined(separator: "\n"))
                }

                let rawCombined = lines.joined(separator: "\n")
                let suspicious = SuspiciousPatternEngine.isSuspicious(rawCombined)
                if suspicious {
                    findings.append(SuspiciousFinding(category: "Firefox profile \(profileName)", description: "Suspicious pattern in extensions or prefs"))
                }

                profileExts.append(
                    FirefoxProfileExtensions(
                        profileName: profileName,
                        rawExtensionsListing: rawCombined.isEmpty ? "(none)" : rawCombined,
                        suspicious: suspicious
                    )
                )
            }
        }

        var globalPolicies: FirefoxPolicies?
        let policiesPath = "/Library/Application Support/Mozilla/ManagedStorage/firefox/policies.json"
        if fm.fileExists(atPath: policiesPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: policiesPath)),
           let raw = String(data: data, encoding: .utf8) {
            let suspicious = SuspiciousPatternEngine.isSuspicious(raw)
            if suspicious {
                findings.append(SuspiciousFinding(category: "Firefox global policies", description: "Suspicious pattern in policies.json"))
            }
            globalPolicies = FirefoxPolicies(raw: raw, suspicious: suspicious)
        }

        return FirefoxCheckResult(installed: installed, profiles: profileExts, globalPolicies: globalPolicies)
    }

    // MARK: - Safari

    static func scanSafari(findings: inout [SuspiciousFinding]) -> SafariCheckResult {
        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser

        let safariDir = homeDir.appendingPathComponent("Library/Safari")
        let extDir = safariDir.appendingPathComponent("Extensions")

        // Check both app bundle locations and the Safari Library folder
        let safariAppPaths = [
            "/Applications/Safari.app",
            "/System/Applications/Safari.app"
        ]
        let safariAppExists = safariAppPaths.contains { fm.fileExists(atPath: $0) }

        var isSafariDir: ObjCBool = false
        let safariDirExists = fm.fileExists(atPath: safariDir.path, isDirectory: &isSafariDir) && isSafariDir.boolValue

        let installed = safariAppExists || safariDirExists
        guard installed else {
            return SafariCheckResult(
                installed: false,
                extensionsListing: nil,
                managedPreferences: nil,
                searchProvider: nil,
                homePage: nil,
                safariExtensionsOutput: nil,
                suspicious: false
            )
        }

        var extListing: String?
        if safariDirExists,
           fm.fileExists(atPath: extDir.path),
           let list = try? fm.contentsOfDirectory(atPath: extDir.path) {
            extListing = list.joined(separator: "\n")
        }

        var extSuspicious = false
        if let e = extListing, SuspiciousPatternEngine.isSuspicious(e) {
            extSuspicious = true
            findings.append(SuspiciousFinding(category: "Safari Extensions", description: "Suspicious pattern in extensions folder"))
        }

        var managedPrefs: String?
        let safariPlist = "/Library/Managed Preferences/com.apple.Safari.plist"
        if fm.fileExists(atPath: safariPlist) {
            managedPrefs = runCommand("/usr/bin/defaults", ["read", "/Library/Managed Preferences/com.apple.Safari"])
            if let m = managedPrefs, SuspiciousPatternEngine.isSuspicious(m) {
                findings.append(SuspiciousFinding(category: "Safari Managed Preferences", description: "Suspicious pattern in managed prefs"))
            }
        }

        let searchProvider = runCommand("/usr/bin/defaults", ["read", "com.apple.Safari", "SearchProviderIdentifier"]).trimmingCharacters(in: .whitespacesAndNewlines)
        let homePage = runCommand("/usr/bin/defaults", ["read", "com.apple.Safari", "HomePage"]).trimmingCharacters(in: .whitespacesAndNewlines)
        let searchHomeCombined = "Search: \(searchProvider) Home: \(homePage)"
        let searchHomeSuspicious = SuspiciousPatternEngine.isSuspicious(searchHomeCombined)
        if searchHomeSuspicious {
            findings.append(SuspiciousFinding(category: "Safari search/homepage", description: "Suspicious pattern in search or homepage"))
        }

        let safariExtOutput = runCommand("/usr/sbin/systemextensionsctl", ["list"])
        let safariExtLines = safariExtOutput
            .components(separatedBy: "\n")
            .filter { $0.lowercased().contains("safari") }
            .joined(separator: "\n")

        let anySuspicious =
            extSuspicious ||
            searchHomeSuspicious ||
            (managedPrefs.map { SuspiciousPatternEngine.isSuspicious($0) } ?? false)

        return SafariCheckResult(
            installed: installed,
            extensionsListing: extListing,
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
        // Filter out our own grep if it appears somehow (paranoia)
            .filter { !$0.contains("egrep") && !$0.contains("grep") }

        let suspicious = SuspiciousPatternEngine.isSuspicious(out)
        if suspicious {
            findings.append(SuspiciousFinding(category: "Browser processes", description: "Suspicious pattern in process list"))
        }

        return lines.map { BrowserProcessInfo(line: $0, suspicious: suspicious) }
    }
}
