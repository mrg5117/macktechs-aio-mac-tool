//
//  BrowserHealthView.swift
//  Macktechs AIO Mac Tool
//
//  Run read-only browser health scan and display structured report.
//

import SwiftUI

struct BrowserHealthView: View {
    @EnvironmentObject var diagnosticStore: DiagnosticStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if diagnosticStore.isRunningFullScan {
                ProgressView("Running browser health scan…")
                    .padding(.vertical)
            }

            if let report = diagnosticStore.browserHealthReport {
                ScrollView {
                    BrowserHealthReportView(report: report)
                }
            } else if !diagnosticStore.isRunningFullScan {
                Text("Run a scan to see browser health details.")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Browser Health Check")
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Browser Health Check")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Read-only scan of browser settings, profiles, extensions, and related system configuration.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: {
                diagnosticStore.runBrowserHealthScan()
            }) {
                Text(diagnosticStore.isRunningFullScan ? "Scanning…" : "Run Scan")
            }
            .buttonStyle(.borderedProminent)
            .disabled(diagnosticStore.isRunningFullScan)
        }
    }
}

#Preview {
    BrowserHealthView()
        .environmentObject(DiagnosticStore())
        .frame(width: 700, height: 500)
}
