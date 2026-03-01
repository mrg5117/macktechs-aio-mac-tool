//
//  InstalledAppsView.swift
//  Macktechs AIO Tool
//
//  Read-only list of installed applications.
//

import SwiftUI

struct InstalledAppsView: View {
    @State private var apps: [InstalledApp] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Installed Applications")
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

            if apps.isEmpty && !isLoading {
                Text("Tap “Scan” to list applications from /Applications and ~/Applications (read-only).")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                Table(apps) {
                    TableColumn("Name") { app in Text(app.name) }
                    TableColumn("Version") { app in Text(app.version ?? "—") }
                    TableColumn("Bundle ID") { app in Text(app.bundleID ?? "—") }
                    TableColumn("Developer") { app in Text(app.developer ?? "—") }
                    TableColumn("Signed") { app in Text(app.isSigned ? "Yes" : "No").foregroundStyle(app.isSigned ? .primary : .orange) }
                    TableColumn("Arch") { app in Text(app.architecture) }
                    TableColumn("Size (MB)") { app in Text(String(format: "%.1f", app.sizeMB)) }
                    TableColumn("Last Opened") { app in Text(app.lastOpened.map { $0.formatted() } ?? "—") }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Installed Applications")
    }

    private func runScan() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = InstalledAppsScanner.scan()
            DispatchQueue.main.async {
                apps = result
                isLoading = false
            }
        }
    }
}

#Preview {
    InstalledAppsView()
        .frame(width: 800, height: 400)
}
