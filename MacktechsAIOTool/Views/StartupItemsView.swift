//
//  StartupItemsView.swift
//  Macktechs AIO Tool
//
//  Read-only display of startup items (LaunchAgents, LaunchDaemons, Login Items).
//

import SwiftUI

struct StartupItemsView: View {
    @State private var userAgents: [StartupItem] = []
    @State private var systemAgents: [StartupItem] = []
    @State private var daemons: [StartupItem] = []
    @State private var loginItems: [StartupItem] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Startup Items")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(isLoading ? "Scanning…" : "Scan") {
                    runScan()
                }
                .disabled(isLoading)
            }
            .padding()

            Divider()

            if userAgents.isEmpty && systemAgents.isEmpty && daemons.isEmpty && loginItems.isEmpty && !isLoading {
                Text("Tap “Scan” to list startup items (read-only).")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                List {
                    section("User LaunchAgents", items: userAgents)
                    section("System LaunchAgents", items: systemAgents)
                    section("LaunchDaemons", items: daemons)
                    section("Login Items", items: loginItems)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Startup Items")
    }

    private func section(_ title: String, items: [StartupItem]) -> some View {
        Group {
            if !items.isEmpty {
                Section(title) {
                    ForEach(items) { item in
                        StartupItemRow(item: item)
                    }
                }
            }
        }
    }

    private func runScan() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let u = StartupScanner.scanLaunchAgents(user: true)
            let s = StartupScanner.scanLaunchAgents(user: false)
            let d = StartupScanner.scanLaunchDaemons()
            let l = StartupScanner.scanLoginItems()
            DispatchQueue.main.async {
                userAgents = u
                systemAgents = s
                daemons = d
                loginItems = l
                isLoading = false
            }
        }
    }
}

struct StartupItemRow: View {
    let item: StartupItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name)
                    .fontWeight(.medium)
                Spacer()
                Text(item.isSigned ? "Signed" : "Unsigned")
                    .font(.caption)
                    .foregroundStyle(item.isSigned ? .secondary : .orange)
            }
            Text(item.path)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let dev = item.developer {
                Text("Developer: \(dev)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let mod = item.modified {
                Text("Modified: \(mod.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !item.notes.isEmpty {
                Text(item.notes.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    StartupItemsView()
        .frame(width: 600, height: 400)
}
