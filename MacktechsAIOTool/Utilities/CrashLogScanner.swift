//
//  CrashLogScanner.swift
//  Macktechs AIO Tool
//
//  Read-only scan of DiagnosticReports and CrashReporter logs.
//

import Foundation

struct CrashLog: Identifiable, Codable, Hashable {
    var id: UUID
    let name: String
    let date: Date
    let type: String
    let process: String
    let summary: String
    let path: String

    init(id: UUID = UUID(), name: String, date: Date, type: String, process: String, summary: String, path: String) {
        self.id = id
        self.name = name
        self.date = date
        self.type = type
        self.process = process
        self.summary = summary
        self.path = path
    }
}

struct CrashLogSummary: Codable {
    let lastCrashTime: Date?
    let totalCount: Int
    let mostFrequentProcess: String?
    let kernelPanicCount: Int
}

enum CrashLogScanner {

    static let maxLogs = 20

    static func scan() -> (logs: [CrashLog], summary: CrashLogSummary) {
        var all: [CrashLog] = []
        let dirs: [(URL, String)] = [
            (FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports"), "crash"),
            (URL(fileURLWithPath: "/Library/Logs/DiagnosticReports"), "crash"),
            (FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/CrashReporter"), "crash"),
        ]
        for (url, typeDefault) in dirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else { continue }
            for fileURL in contents {
                let name = fileURL.lastPathComponent
                let type = fileType(from: name)
                let (process, date) = parseFilename(name)
                let summaryText = readFirstLines(fileURL, count: 10)
                all.append(CrashLog(
                    name: name,
                    date: date ?? (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date) ?? Date(),
                    type: type,
                    process: process ?? "Unknown",
                    summary: summaryText,
                    path: fileURL.path
                ))
            }
        }
        all.sort { $0.date > $1.date }
        let limited = Array(all.prefix(maxLogs))
        let summary = buildSummary(logs: all)
        return (limited, summary)
    }

    private static func fileType(from name: String) -> String {
        if name.hasSuffix(".ips") { return "panic" }
        if name.hasSuffix(".hang") { return "hang" }
        return "crash"
    }

    private static func parseFilename(_ name: String) -> (process: String?, date: Date?) {
        let noExt = (name as NSString).deletingPathExtension
        let parts = noExt.split(separator: "_", omittingEmptySubsequences: false)
        var process: String?
        var date: Date?
        if parts.count >= 2 {
            process = String(parts[0])
            let datePart = String(parts[1])
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"
            date = formatter.date(from: datePart)
            if date == nil {
                formatter.dateFormat = "yyyy-MM-dd"
                date = formatter.date(from: datePart)
            }
        }
        return (process, date)
    }

    private static func readFirstLines(_ url: URL, count: Int) -> String {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.prefix(count).joined(separator: "\n")
    }

    private static func buildSummary(logs: [CrashLog]) -> CrashLogSummary {
        let lastCrash = logs.max(by: { $0.date < $1.date }).map(\.date)
        let panicCount = logs.filter { $0.type == "panic" }.count
        let processCounts = Dictionary(grouping: logs, by: { $0.process }).mapValues(\.count)
        let mostFrequent = processCounts.max(by: { $0.value < $1.value }).map(\.key)
        return CrashLogSummary(
            lastCrashTime: lastCrash,
            totalCount: logs.count,
            mostFrequentProcess: mostFrequent,
            kernelPanicCount: panicCount
        )
    }
}
