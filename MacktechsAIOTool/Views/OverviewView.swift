//
//  OverviewView.swift
//  Macktechs AIO Tool
//
//  Dashboard: Mac hardware info and battery (cycles, health %).
//

import SwiftUI

struct OverviewView: View {
    private let macInfo = getMacInfo()
    private let battery = getBatteryInfo()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Overview")
                    .font(.title)
                    .fontWeight(.semibold)

                GroupBox(label: Label("Hardware", systemImage: "laptopcomputer")) {
                    VStack(alignment: .leading, spacing: 10) {
                        row("Model identifier", macInfo.modelIdentifier)
                        if let name = macInfo.marketingName {
                            row("Model", name)
                        }
                        row("CPU", macInfo.cpu)
                        row("Memory", "\(macInfo.memoryGB) GB")
                        row("Storage (total)", "\(macInfo.totalDiskGB) GB")
                        row("Storage (free)", "\(macInfo.freeDiskGB) GB")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox(label: Label("Battery", systemImage: "battery.100")) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let cycles = battery.cycleCount {
                            row("Cycle count", "\(cycles)")
                        } else {
                            row("Cycle count", "—")
                        }
                        if let health = battery.healthPercent {
                            row("Battery health", "\(health)%")
                        } else {
                            row("Battery health", "—")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Overview")
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    OverviewView()
        .frame(width: 500, height: 400)
}
