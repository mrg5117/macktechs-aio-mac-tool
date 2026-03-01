//
//  DiagnosticReport.swift
//  Macktechs AIO Mac Tool
//
//  Aggregated read-only diagnostic data for JSON/HTML export.
//

import Foundation

struct DiagnosticReport: Codable {
    let timestamp: Date
    let macInfo: MacInfo
    let batteryInfo: BatteryInfo
    let browserHealthOutput: String
    let startupItems: [StartupItem]
    let installedApps: [InstalledApp]
    let crashLogs: [CrashLog]
    let crashSummary: CrashLogSummary
    let networkInfo: NetworkInfo
    let securityFindings: [SecurityFinding]
}
