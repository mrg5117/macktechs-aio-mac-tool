//
//  NetworkScanner.swift
//  Macktechs AIO Mac Tool
//
//  Read-only network diagnostics: interfaces, DNS, proxy, Wi‑Fi, ping.
//

import Foundation

struct PingResult: Codable {
    let host: String
    let reachable: Bool
    let latencyMs: Double?
}

struct WiFiInfo: Codable {
    let ssid: String?
    let rssi: Int?
    let channel: Int?
}

struct NetworkInfo: Codable {
    let interface: String
    let ipAddress: String?
    let router: String?
    let dns: [String]
    let proxies: [String: String]
    let wifi: WiFiInfo?
    let pingResults: [PingResult]
}

enum NetworkScanner {

    static func scan() -> NetworkInfo {
        let iface = primaryInterface()
        let ip = getIPAddress(interface: iface)
        let router = getRouter()
        let dns = getDNS()
        let proxies = getProxies()
        let wifi = getWiFiInfo()
        let pingResults = runPings()
        return NetworkInfo(
            interface: iface,
            ipAddress: ip,
            router: router,
            dns: dns,
            proxies: proxies,
            wifi: wifi,
            pingResults: pingResults
        )
    }

    static func primaryInterface() -> String {
        runCommand("/usr/sbin/system_profiler", args: ["SPNetworkDataType"])?.contains("Wi-Fi") == true ? "Wi-Fi" : "en0"
    }

    static func getIPAddress(interface: String) -> String? {
        let output = runCommand("/sbin/ifconfig", args: [interface]) ?? ""
        let inetMatch = output.range(of: #"inet (\d+\.\d+\.\d+\.\d+)"#, options: .regularExpression)
        guard let range = inetMatch else { return nil }
        let line = String(output[range])
        let numMatch = line.range(of: #"\d+\.\d+\.\d+\.\d+"#, options: .regularExpression)
        guard let r = numMatch else { return nil }
        return String(line[r])
    }

    static func getRouter() -> String? {
        runCommand("/usr/sbin/netstat", args: ["-nr", "-f", "inet"])
            .flatMap { out in
                out.components(separatedBy: "\n").first(where: { $0.contains("default") })?
                    .split(separator: " ")
                    .compactMap { String($0) }
                    .dropFirst()
                    .first
            }
    }

    static func getDNS() -> [String] {
        let output = runCommand("/usr/sbin/scutil", args: ["--dns"]) ?? ""
        var servers: [String] = []
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("nameserver") {
                let parts = trimmed.split(separator: " ", maxSplits: 1)
                if parts.count == 2 {
                    servers.append(String(parts[1]))
                }
            }
        }
        return Array(Set(servers)).sorted()
    }

    static func getProxies() -> [String: String] {
        var result: [String: String] = [:]
        for key in ["HTTP", "HTTPS"] {
            let out = runCommand("/usr/sbin/networksetup", args: ["-get\(key)proxy", "Wi-Fi"]) ?? ""
            for line in out.components(separatedBy: "\n") {
                if line.contains("Enabled: Yes") { result["\(key) Proxy Enabled"] = "Yes" }
                if line.contains("Server:") { result["\(key) Server"] = line.replacingOccurrences(of: "Server:", with: "").trimmingCharacters(in: .whitespaces) }
                if line.contains("Port:") { result["\(key) Port"] = line.replacingOccurrences(of: "Port:", with: "").trimmingCharacters(in: .whitespaces) }
            }
        }
        return result
    }

    static func getWiFiInfo() -> WiFiInfo? {
        let path = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let output = runCommand(path, args: ["-I"]) ?? ""
        var ssid: String?
        var rssi: Int?
        var channel: Int?
        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                switch parts[0] {
                case "SSID": ssid = parts[1]
                case "agrCtlRSSI": rssi = Int(parts[1])
                case "channel": channel = Int(parts[1])
                default: break
                }
            }
        }
        return WiFiInfo(ssid: ssid, rssi: rssi, channel: channel)
    }

    static func runPings() -> [PingResult] {
        let hosts = ["1.1.1.1", "8.8.8.8"]
        return hosts.map { host in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-t", "3", host]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            let start = Date()
            try? process.run()
            process.waitUntilExit()
            let elapsed = Date().timeIntervalSince(start) * 1000
            let reachable = process.terminationStatus == 0
            return PingResult(
                host: host,
                reachable: reachable,
                latencyMs: reachable ? elapsed : nil
            )
        }
    }

    private static func runCommand(_ launchPath: String, args: [String]) -> String? {
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
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
