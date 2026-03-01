//
//  DiagnosticStore.swift
//  Macktechs AIO Tool
//
//  Holds last report folder and runs full diagnostic (read-only).
//

import Foundation
import AppKit
import SwiftUI

@MainActor
final class DiagnosticStore: ObservableObject {
    @Published var lastReportFolderURL: URL?
    @Published var isRunningFullScan = false
    @Published var lastReportDate: Date?
    @Published var scanError: String?
    /// Path to show in UI after report is saved (e.g. for alert).
    @Published var reportSavedPath: String?

    /// Runs all Phase One + Phase Two scanners, generates JSON + HTML in ~/Documents/Macktechs AIO Reports/<timestamp>/
    func runFullDiagnostic() {
        guard !isRunningFullScan else { return }
        isRunningFullScan = true
        scanError = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performFullScan()
        }
    }

    private func performFullScan() {
        let macInfo = getMacInfo()
        let batteryInfo = getBatteryInfo()
        let browserOutput = runBrowserHealthScriptSync()
        let userAgents = StartupScanner.scanLaunchAgents(user: true)
        let systemAgents = StartupScanner.scanLaunchAgents(user: false)
        let daemons = StartupScanner.scanLaunchDaemons()
        let loginItems = StartupScanner.scanLoginItems()
        let allStartup = userAgents + systemAgents + daemons + loginItems
        let installedApps = InstalledAppsScanner.scan()
        let (crashLogs, crashSummary) = CrashLogScanner.scan()
        let networkInfo = NetworkScanner.scan()
        let securityFindings = SecurityScanner.scan(startupItems: allStartup)

        let report = DiagnosticReport(
            timestamp: Date(),
            macInfo: macInfo,
            batteryInfo: batteryInfo,
            browserHealthOutput: browserOutput,
            startupItems: allStartup,
            installedApps: installedApps,
            crashLogs: crashLogs,
            crashSummary: crashSummary,
            networkInfo: networkInfo,
            securityFindings: securityFindings
        )

        let folderURL = ReportGenerator.createReportFolder()
        _ = ReportGenerator.generateJSONReport(report: report, to: folderURL)
        _ = ReportGenerator.generateHTMLReport(report: report, to: folderURL)

        DispatchQueue.main.async { [weak self] in
            self?.lastReportFolderURL = folderURL
            self?.lastReportDate = report.timestamp
            self?.isRunningFullScan = false
            self?.reportSavedPath = folderURL.path
        }
    }

    /// Opens Mail with report files attached (does not send). Uses share sheet or Finder.
    func emailReport() {
        guard let folder = lastReportFolderURL else {
            return
        }
        let jsonURL = folder.appendingPathComponent("report.json")
        let htmlURL = folder.appendingPathComponent("report.html")
        guard FileManager.default.fileExists(atPath: jsonURL.path),
              FileManager.default.fileExists(atPath: htmlURL.path) else {
            return
        }
        let items: [Any] = [htmlURL, jsonURL]
        let picker = NSSharingServicePicker(items: items)
        if let view = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }

    /// Opens Finder at the report folder.
    func revealReportInFinder() {
        guard let url = lastReportFolderURL else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}
