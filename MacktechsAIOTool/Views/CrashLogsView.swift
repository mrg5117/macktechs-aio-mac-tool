//
//  CrashLogsView.swift
//  Macktechs AIO Mac Tool
//
//  Read-only display of recent crash logs and summary.
//

import SwiftUI

struct CrashLogsView: View {
    @State private var logs: [CrashLog] = []
    @State private var summary: CrashLogSummary?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Crash Logs")
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

            if logs.isEmpty && !isLoading {
                Text("Tap “Scan” to list recent crash logs (read-only).")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                List {
                    if let s = summary {
                        Section("Summary") {
                            if let t = s.lastCrashTime {
                                LabeledContent("Last crash", value: t.formatted())
                            }
                            LabeledContent("Total logs found", value: "\(s.totalCount)")
                            LabeledContent("Kernel panics", value: "\(s.kernelPanicCount)")
                            if let p = s.mostFrequentProcess {
                                LabeledContent("Most frequent process", value: p)
                            }
                        }
                    }
                    Section("Recent logs (up to \(CrashLogScanner.maxLogs))") {
                        ForEach(logs) { log in
                            CrashLogRow(log: log)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Crash Logs")
    }

    private func runScan() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let (l, s) = CrashLogScanner.scan()
            DispatchQueue.main.async {
                logs = l
                summary = s
                isLoading = false
            }
        }
    }
}

struct CrashLogRow: View {
    let log: CrashLog
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.process)
                    .fontWeight(.medium)
                Text(log.type)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .background(log.type == "panic" ? Color.red.opacity(0.2) : Color.orange.opacity(0.2))
                    .cornerRadius(4)
                Spacer()
                Text(log.date.formatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(log.name)
                .font(.caption)
                .foregroundStyle(.secondary)
            if expanded && !log.summary.isEmpty {
                Text(log.summary)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { expanded.toggle() }
    }
}

#Preview {
    CrashLogsView()
        .frame(width: 600, height: 400)
}
