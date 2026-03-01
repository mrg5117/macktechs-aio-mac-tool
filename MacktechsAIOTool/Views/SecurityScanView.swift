//
//  SecurityScanView.swift
//  Macktechs AIO Mac Tool
//
//  Read-only security findings: profiles, SIP, Gatekeeper, XProtect, hosts, etc.
//

import SwiftUI

struct SecurityScanView: View {
    @State private var findings: [SecurityFinding] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Security Scan")
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

            if findings.isEmpty && !isLoading {
                Text("Tap “Scan” to run read-only security checks (profiles, SIP, Gatekeeper, XProtect, MRT, hosts, startup items).")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                List {
                    ForEach(findings) { f in
                        SecurityFindingRow(finding: f)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Security Scan")
    }

    private func runScan() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let startupItems = StartupScanner.scanLaunchAgents(user: true)
                + StartupScanner.scanLaunchAgents(user: false)
                + StartupScanner.scanLaunchDaemons()
                + StartupScanner.scanLoginItems()
            let result = SecurityScanner.scan(startupItems: startupItems)
            DispatchQueue.main.async {
                findings = result
                isLoading = false
            }
        }
    }
}

struct SecurityFindingRow: View {
    let finding: SecurityFinding

    var severityColor: Color {
        switch finding.severity {
        case "Critical": return .red
        case "Warning": return .orange
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(finding.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(finding.severity)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(severityColor)
            }
            Text(finding.title)
                .fontWeight(.medium)
            Text(finding.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(5)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SecurityScanView()
        .frame(width: 600, height: 400)
}
