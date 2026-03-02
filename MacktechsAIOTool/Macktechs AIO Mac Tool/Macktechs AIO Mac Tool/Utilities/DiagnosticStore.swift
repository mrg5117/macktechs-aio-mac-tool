import Foundation
import Combine

final class DiagnosticStore: ObservableObject {
    @Published var lastReportFolderURL: URL?
    @Published var isRunningFullScan: Bool = false
    @Published var lastReportDate: Date?
    @Published var reportSavedPath: String?
}
