//
//  BrowserHealthView.swift
//  Macktechs AIO Mac Tool
//
//  Runs bundled browser_health_check.sh and shows output in a scrollable log-style view.
//

import SwiftUI

struct BrowserHealthView: View {
    @State private var output: String = ""
    @State private var isRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Browser Health Check")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(isRunning ? "Running…" : "Run Browser Health Scan") {
                    runScan()
                }
                .disabled(isRunning)
            }
            .padding()

            Divider()

            ScrollView([.vertical, .horizontal]) {
                Text(output.isEmpty ? "No scan run yet." : output)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .textSelection(.enabled)
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Browser Health Check")
    }

    private func runScan() {
        isRunning = true
        output = ""
        BrowserHealthRunner.run { result in
            output = result
            isRunning = false
        }
    }
}

#Preview {
    BrowserHealthView()
        .frame(width: 600, height: 400)
}
