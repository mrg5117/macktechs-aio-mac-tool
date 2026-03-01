//
//  ContentView.swift
//  Macktechs AIO Mac Tool
//
//  Single-window, Malwarebytes-style layout: sidebar + detail.
//

import SwiftUI

enum SidebarItem: Hashable {
    case overview
    case browserHealth
    case systemHealth
    case startupItems
    case installedApps
    case crashLogs
    case networkDiagnostics
    case security
}

struct ContentView: View {
    @EnvironmentObject var diagnosticStore: DiagnosticStore
    @State private var selection: SidebarItem? = .overview
    @State private var showReportSavedAlert = false
    @State private var reportSavedPathForAlert: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("General") {
                    NavigationLink(value: SidebarItem.overview) {
                        Label("Overview", systemImage: "laptopcomputer")
                    }
                }

                Section("Diagnostics") {
                    NavigationLink(value: SidebarItem.browserHealth) {
                        Label("Browser Health Check", systemImage: "globe")
                    }
                    NavigationLink(value: SidebarItem.systemHealth) {
                        Label("System Health", systemImage: "speedometer")
                    }
                    NavigationLink(value: SidebarItem.startupItems) {
                        Label("Startup Items", systemImage: "power")
                    }
                    NavigationLink(value: SidebarItem.installedApps) {
                        Label("Installed Applications", systemImage: "app.badge")
                    }
                    NavigationLink(value: SidebarItem.crashLogs) {
                        Label("Crash Logs", systemImage: "exclamationmark.triangle")
                    }
                    NavigationLink(value: SidebarItem.networkDiagnostics) {
                        Label("Network Diagnostics", systemImage: "network")
                    }
                    NavigationLink(value: SidebarItem.security) {
                        Label("Security Scan", systemImage: "shield.lefthalf.filled")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            Group {
                switch selection ?? .overview {
                case .overview:
                    OverviewView()
                case .browserHealth:
                    BrowserHealthView()
                case .systemHealth:
                    SystemHealthView()
                case .startupItems:
                    StartupItemsView()
                case .installedApps:
                    InstalledAppsView()
                case .crashLogs:
                    CrashLogsView()
                case .networkDiagnostics:
                    NetworkDiagnosticsView()
                case .security:
                    SecurityScanView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(diagnosticStore.isRunningFullScan ? "Running…" : "Run Full Diagnostic") {
                    diagnosticStore.runFullDiagnostic()
                }
                .disabled(diagnosticStore.isRunningFullScan)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Export / Email Report…") {
                    if diagnosticStore.lastReportFolderURL != nil {
                        diagnosticStore.emailReport()
                    }
                }
                .disabled(diagnosticStore.lastReportFolderURL == nil)
                .help("Share or email the latest report. Run Full Diagnostic first to generate a report.")
            }
        }
        .onChange(of: diagnosticStore.reportSavedPath) { path in
            if let p = path {
                reportSavedPathForAlert = p
                showReportSavedAlert = true
            }
        }
        .alert("Report saved", isPresented: $showReportSavedAlert) {
            Button("Reveal in Finder") {
                diagnosticStore.revealReportInFinder()
                diagnosticStore.reportSavedPath = nil
            }
            Button("OK") {
                diagnosticStore.reportSavedPath = nil
            }
        } message: {
            if let p = reportSavedPathForAlert {
                Text("Report saved to:\n\(p)\n\nYou can export or email it from the toolbar.")
            }
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 900, height: 600)
}
