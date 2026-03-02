//
//  ContentView.swift
//  Macktechs AIO Mac Tool
//
//  Single-window, sidebar + detail. Read-only diagnostics.
//

import SwiftUI

enum SidebarItem: Hashable {
    case overview
    case browserHealth
    case systemHealth
    case crashLogs
    case networkDiagnostics
    case securityScan
}

struct ContentView: View {
    @EnvironmentObject var diagnosticStore: DiagnosticStore
    @State private var selection: SidebarItem? = .overview

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
                    NavigationLink(value: SidebarItem.crashLogs) {
                        Label("Crash Logs", systemImage: "exclamationmark.triangle")
                    }
                    NavigationLink(value: SidebarItem.networkDiagnostics) {
                        Label("Network Diagnostics", systemImage: "network")
                    }
                    NavigationLink(value: SidebarItem.securityScan) {
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
                case .crashLogs:
                    CrashLogsView()
                case .networkDiagnostics:
                    NetworkDiagnosticsView()
                case .securityScan:
                    SecurityScanView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DiagnosticStore())
        .frame(width: 900, height: 600)
}
