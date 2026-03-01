//
//  ReportGenerator.swift
//  Macktechs AIO Tool
//
//  Creates timestamped report folder, JSON and HTML reports (read-only).
//

import Foundation

enum ReportGenerator {

    static let reportsDirectoryName = "Macktechs AIO Reports"

    /// Creates ~/Documents/Macktechs AIO Reports/<timestamp>/ and returns its URL.
    static func createReportFolder() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let reportsRoot = docs.appendingPathComponent(reportsDirectoryName, isDirectory: true)
        let folder = reportsRoot.appendingPathComponent(timestamp, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Writes report.json to the given folder and returns the file URL.
    static func generateJSONReport(report: DiagnosticReport, to folderURL: URL) -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = folderURL.appendingPathComponent("report.json")
        if let data = try? encoder.encode(report) {
            try? data.write(to: url)
        }
        return url
    }

    /// Writes report.html to the given folder and returns the file URL.
    static func generateHTMLReport(report: DiagnosticReport, to folderURL: URL) -> URL {
        let html = buildHTML(report)
        let url = folderURL.appendingPathComponent("report.html")
        try? html.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func buildHTML(_ report: DiagnosticReport) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .medium
        let dateStr = dateFormatter.string(from: report.timestamp)

        var sections: [String] = []
        sections.append("""
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><title>Macktechs AIO Report</title>
        <style>
        body { font-family: -apple-system, sans-serif; margin: 24px; background: #f5f5f5; }
        h1 { color: #333; }
        h2 { margin-top: 24px; color: #555; border-bottom: 1px solid #ccc; }
        .section { background: #fff; padding: 16px; margin: 16px 0; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 12px; }
        .badge-Critical { background: #fcc; color: #800; }
        .badge-Warning { background: #ffc; color: #840; }
        .badge-Info { background: #eef; color: #448; }
        table { border-collapse: collapse; width: 100%; }
        th, td { text-align: left; padding: 8px; border-bottom: 1px solid #eee; }
        pre { overflow-x: auto; font-size: 12px; background: #f8f8f8; padding: 12px; border-radius: 4px; }
        details { margin: 8px 0; }
        </style></head><body>
        <h1>Macktechs AIO Tool — Diagnostic Report</h1>
        <p>Generated: \(dateStr)</p>
        """)

        sections.append("""
        <div class="section"><h2>Hardware</h2>
        <table>
        <tr><th>Model</th><td>\(report.macInfo.modelIdentifier)</td></tr>
        <tr><th>CPU</th><td>\(escape(report.macInfo.cpu))</td></tr>
        <tr><th>Memory</th><td>\(report.macInfo.memoryGB) GB</td></tr>
        <tr><th>Disk (total / free)</th><td>\(report.macInfo.totalDiskGB) GB / \(report.macInfo.freeDiskGB) GB</td></tr>
        <tr><th>Battery cycles</th><td>\(report.batteryInfo.cycleCount.map { "\($0)" } ?? "—")</td></tr>
        <tr><th>Battery health</th><td>\(report.batteryInfo.healthPercent.map { "\($0)%" } ?? "—")</td></tr>
        </table></div>
        """)

        sections.append("""
        <div class="section"><h2>Browser Health</h2>
        <details><summary>Output</summary><pre>\(escape(report.browserHealthOutput))</pre></details>
        </div>
        """)

        sections.append("""
        <div class="section"><h2>Startup Items</h2>
        <table><tr><th>Name</th><th>Path</th><th>Signed</th><th>Source</th></tr>
        \(report.startupItems.map { "<tr><td>\(escape($0.name))</td><td>\(escape($0.path))</td><td>\($0.isSigned ? "Yes" : "No")</td><td>\(escape($0.source))</td></tr>" }.joined())
        </table></div>
        """)

        sections.append("""
        <div class="section"><h2>Installed Applications</h2>
        <table><tr><th>Name</th><th>Version</th><th>Bundle ID</th><th>Signed</th><th>Arch</th><th>Size (MB)</th></tr>
        \(report.installedApps.prefix(200).map { "<tr><td>\(escape($0.name))</td><td>\(escape($0.version ?? "—"))</td><td>\(escape($0.bundleID ?? "—"))</td><td>\($0.isSigned ? "Yes" : "No")</td><td>\($0.architecture)</td><td>\(String(format: "%.1f", $0.sizeMB))</td></tr>" }.joined())
        </table><p>(First 200 apps shown)</p></div>
        """)

        sections.append("""
        <div class="section"><h2>Crash Logs (summary)</h2>
        <p>Total: \(report.crashSummary.totalCount), Kernel panics: \(report.crashSummary.kernelPanicCount), Most frequent: \(escape(report.crashSummary.mostFrequentProcess ?? "—"))</p>
        <details><summary>Recent logs</summary>
        <table><tr><th>Process</th><th>Type</th><th>Date</th></tr>
        \(report.crashLogs.prefix(20).map { "<tr><td>\(escape($0.process))</td><td>\($0.type)</td><td>\($0.date.formatted())</td></tr>" }.joined())
        </table></details></div>
        """)

        sections.append("""
        <div class="section"><h2>Network</h2>
        <table>
        <tr><th>Interface</th><td>\(report.networkInfo.interface)</td></tr>
        <tr><th>IP</th><td>\(report.networkInfo.ipAddress ?? "—")</td></tr>
        <tr><th>Router</th><td>\(report.networkInfo.router ?? "—")</td></tr>
        <tr><th>DNS</th><td>\(report.networkInfo.dns.joined(separator: ", "))</td></tr>
        <tr><th>Ping 1.1.1.1</th><td>\(report.networkInfo.pingResults.first(where: { $0.host == "1.1.1.1" })?.reachable == true ? "OK" : "Fail")</td></tr>
        <tr><th>Ping 8.8.8.8</th><td>\(report.networkInfo.pingResults.first(where: { $0.host == "8.8.8.8" })?.reachable == true ? "OK" : "Fail")</td></tr>
        </table></div>
        """)

        sections.append("""
        <div class="section"><h2>Security Findings</h2>
        <table><tr><th>Category</th><th>Title</th><th>Severity</th><th>Detail</th></tr>
        \(report.securityFindings.map { "<tr><td>\(escape($0.category))</td><td>\(escape($0.title))</td><td><span class=\"badge badge-\($0.severity)\">\($0.severity)</span></td><td>\(escape($0.detail))</td></tr>" }.joined())
        </table></div>
        """)

        sections.append("</body></html>")
        return sections.joined()
    }

    private static func escape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
