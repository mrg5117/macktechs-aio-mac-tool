//
//  DiagnosticStore.swift
//  Macktechs AIO Mac Tool
//
//  Minimal store for diagnostics (read-only). Expand later for full report generation.
//

import Foundation
import SwiftUI

@MainActor
final class DiagnosticStore: ObservableObject {
    @Published var lastReportFolderURL: URL?
    @Published var isRunningFullScan = false
    @Published var lastReportDate: Date?
    @Published var reportSavedPath: String?
}
