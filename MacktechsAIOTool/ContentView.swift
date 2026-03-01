//
//  ContentView.swift
//  Macktechs AIO Tool
//
//  Single-window, Malwarebytes-style layout: sidebar + detail.
//

import SwiftUI

enum SidebarItem: Hashable {
    case overview
    case browserHealth
    case systemHealth
    case security
}

struct ContentView: View {
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
                        Label("Browser Health", systemImage: "globe")
                    }
                    NavigationLink(value: SidebarItem.systemHealth) {
                        Label("System Health", systemImage: "speedometer")
                    }
                    NavigationLink(value: SidebarItem.security) {
                        Label("Security & Malware", systemImage: "shield.lefthalf.filled")
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
                case .security:
                    SecurityView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 900, height: 600)
}
