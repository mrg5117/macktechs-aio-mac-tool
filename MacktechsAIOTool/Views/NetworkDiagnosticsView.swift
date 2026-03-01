//
//  NetworkDiagnosticsView.swift
//  Macktechs AIO Tool
//
//  Read-only network info: interface, IP, DNS, proxy, Wi‑Fi, ping.
//

import SwiftUI

struct NetworkDiagnosticsView: View {
    @State private var info: NetworkInfo?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Network Diagnostics")
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

            if info == nil && !isLoading {
                Text("Tap “Scan” to run read-only network diagnostics.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else if let info = info {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        GroupBox(label: Label("Interface", systemImage: "network")) {
                            row("Primary interface", info.interface)
                            row("IP address", info.ipAddress ?? "—")
                            row("Router", info.router ?? "—")
                        }
                        GroupBox(label: Label("DNS", systemImage: "globe")) {
                            if info.dns.isEmpty {
                                Text("—").foregroundStyle(.secondary)
                            } else {
                                ForEach(info.dns, id: \.self) { Text($0).textSelection(.enabled) }
                            }
                        }
                        GroupBox(label: Label("Proxy", systemImage: "arrow.triangle.2.circlepath")) {
                            if info.proxies.isEmpty {
                                Text("None").foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(info.proxies.keys.sorted()), id: \.self) { key in
                                    if let v = info.proxies[key] {
                                        row(key, v)
                                    }
                                }
                            }
                        }
                        if let wifi = info.wifi {
                            GroupBox(label: Label("Wi‑Fi", systemImage: "wifi")) {
                                row("SSID", wifi.ssid ?? "—")
                                if let r = wifi.rssi { row("RSSI", "\(r)") }
                                if let c = wifi.channel { row("Channel", "\(c)") }
                            }
                        }
                        GroupBox(label: Label("Ping", systemImage: "antenna.radiowaves.left.and.right")) {
                            ForEach(info.pingResults, id: \.host) { p in
                                HStack {
                                    Text(p.host)
                                    Spacer()
                                    if p.reachable, let lat = p.latencyMs {
                                        Text(String(format: "%.0f ms", lat)).foregroundStyle(.green)
                                    } else {
                                        Text("Unreachable").foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Network Diagnostics")
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
    }

    private func runScan() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = NetworkScanner.scan()
            DispatchQueue.main.async {
                info = result
                isLoading = false
            }
        }
    }
}

#Preview {
    NetworkDiagnosticsView()
        .frame(width: 500, height: 400)
}
