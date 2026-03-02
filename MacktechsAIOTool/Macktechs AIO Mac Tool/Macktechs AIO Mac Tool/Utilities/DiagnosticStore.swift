//
//  DiagnosticStore.swift
//  Macktechs AIO Mac Tool
//
//  Holds diagnostic state and runs read-only browser health scan.
//

import Foundation
import SwiftUI

@MainActor
final class DiagnosticStore: ObservableObject {
    @Published var lastReportFolderURL: URL?
    @Published var isRunningFullScan: Bool = false
    @Published var lastReportDate: Date?
    @Published var reportSavedPath: String?
    @Published var browserHealthReport: BrowserHealthReport?

    private static let reportsDirectoryName = "Macktechs AIO Mac Tool Reports"

    /// Runs the Swift browser health scanner (read-only). Optionally saves JSON to ~/Documents/Macktechs AIO Mac Tool Reports/<timestamp>/
    func runBrowserHealthScan() {
        guard !isRunningFullScan else { return }
        isRunningFullScan = true
        browserHealthReport = nil

        Task {
            let report = await BrowserHealthScanner.runFullScan()
            let folderURL = saveBrowserHealthReportJSON(report)
            await MainActor.run {
                self.browserHealthReport = report
                self.lastReportDate = report.generatedAt
                if let url = folderURL {
                    self.lastReportFolderURL = url
                    self.reportSavedPath = url.path
                }
                self.isRunningFullScan = false
            }
        }
    }

    /// Saves report as JSON; returns folder URL if successful.
    private func saveBrowserHealthReportJSON(_ report: BrowserHealthReport) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: report.generatedAt)
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let root = docs.appendingPathComponent(Self.reportsDirectoryName, isDirectory: true)
        let folder = root.appendingPathComponent(timestamp, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileURL = folder.appendingPathComponent("browser_health_report.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(report) else { return nil }
        try? data.write(to: fileURL)
        return folder
    }
}
