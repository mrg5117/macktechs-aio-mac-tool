//
//  BrowserHealthReportView.swift
//  Macktechs AIO Mac Tool
//
//  Renders BrowserHealthReport with DisclosureGroups and monospaced raw data.
//

import SwiftUI

struct BrowserHealthReportView: View {
    let report: BrowserHealthReport

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summarySection

            DisclosureGroup("Hosts") {
                monospacedBlock(report.hosts.contents)
                if report.hosts.suspicious {
                    Label("Suspicious patterns may be present", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }

            DisclosureGroup("DNS & Proxies") {
                ForEach(report.dns, id: \.serviceName) { d in
                    Text("\(d.serviceName): \(d.servers.joined(separator: ", "))")
                        .font(.system(.caption, design: .monospaced))
                }
                ForEach(report.proxies, id: \.serviceName) { p in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Web: \(p.webProxy ?? "—")").font(.system(.caption, design: .monospaced))
                        Text("Secure: \(p.secureProxy ?? "—")").font(.system(.caption, design: .monospaced))
                        if p.suspicious {
                            Text("Suspicious").foregroundStyle(.orange).font(.caption)
                        }
                    }
                }
            }

            DisclosureGroup("LaunchAgents & LaunchDaemons") {
                ForEach(report.launchEntries) { e in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("[\(e.kind)] \(e.path)")
                            .font(.system(.caption, design: .monospaced))
                        if e.suspicious {
                            Text("Suspicious").foregroundStyle(.orange).font(.caption2)
                        }
                    }
                }
            }

            DisclosureGroup("Login Items") {
                Text(report.loginItems.items.joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                if report.loginItems.suspicious {
                    Text("Suspicious").foregroundStyle(.orange).font(.caption)
                }
            }

            DisclosureGroup("Chrome") {
                Text("Installed: \(report.chrome.installed ? "Yes" : "No")")
                Text("Profiles: \(report.chrome.profiles.joined(separator: ", "))")
                    .font(.system(.caption, design: .monospaced))
                ForEach(report.chrome.extensions) { ext in
                    Text("\(ext.extensionID) | \(ext.name)")
                        .font(.system(.caption, design: .monospaced))
                    if ext.suspicious { Text("Suspicious").foregroundStyle(.orange).font(.caption2) }
                }
                if let prefs = report.chrome.managedPreferences {
                    monospacedBlock(prefs.raw)
                    if prefs.suspicious { Text("Suspicious").foregroundStyle(.orange).font(.caption) }
                }
            }

            DisclosureGroup("Firefox") {
                Text("Installed: \(report.firefox.installed ? "Yes" : "No")")
                ForEach(report.firefox.profiles) { p in
                    Text("Profile: \(p.profileName)").fontWeight(.medium)
                    monospacedBlock(p.rawExtensionsListing)
                    if p.suspicious { Text("Suspicious").foregroundStyle(.orange).font(.caption) }
                }
                if let pol = report.firefox.globalPolicies {
                    monospacedBlock(pol.raw)
                    if pol.suspicious { Text("Suspicious").foregroundStyle(.orange).font(.caption) }
                }
            }

            DisclosureGroup("Safari") {
                Text("Installed: \(report.safari.installed ? "Yes" : "No")")
                Text("Search: \(report.safari.searchProvider ?? "—")")
                Text("Home: \(report.safari.homePage ?? "—")")
                if let ext = report.safari.extensionsListing {
                    monospacedBlock(ext)
                }
                if let prefs = report.safari.managedPreferences {
                    monospacedBlock(prefs)
                }
                if let sysExt = report.safari.safariExtensionsOutput {
                    monospacedBlock(sysExt)
                }
                if report.safari.suspicious {
                    Text("Suspicious").foregroundStyle(.orange).font(.caption)
                }
            }

            DisclosureGroup("Browser Processes") {
                ForEach(report.browserProcesses) { p in
                    Text(p.line)
                        .font(.system(.caption, design: .monospaced))
                }
                if report.browserProcesses.contains(where: { $0.suspicious }) {
                    Text("Suspicious").foregroundStyle(.orange).font(.caption)
                }
            }

            DisclosureGroup("Suspicious Summary") {
                if report.suspiciousSummary.isEmpty {
                    Text("No known bad patterns matched. Manual review still recommended.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(report.suspiciousSummary) { f in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.category).fontWeight(.medium)
                            Text(f.description).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Generated: \(dateFormatter.string(from: report.generatedAt))")
                .font(.subheadline)
            Text("macOS \(report.macOSVersion) · \(report.architecture)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Suspicious findings: \(report.suspiciousSummary.count)")
                .font(.caption)
                .foregroundColor(report.suspiciousSummary.isEmpty ? Color.secondary : Color.orange)
        }
    }

    private func monospacedBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(4)
    }
}

#Preview {
    ScrollView {
        BrowserHealthReportView(report: BrowserHealthReport(
            generatedAt: Date(),
            macOSVersion: "14.0",
            architecture: "arm64",
            hosts: HostsCheckResult(contents: "127.0.0.1 localhost", suspicious: false),
            dns: [DNSCheckResult(serviceName: "Wi-Fi", servers: ["1.1.1.1"])],
            proxies: [ProxyCheckResult(serviceName: "Wi-Fi", webProxy: nil, secureProxy: nil, suspicious: false)],
            launchEntries: [],
            loginItems: LoginItemsResult(items: [], suspicious: false),
            chrome: ChromeCheckResult(installed: false, profiles: [], extensions: [], managedPreferences: nil),
            firefox: FirefoxCheckResult(installed: false, profiles: [], globalPolicies: nil),
            safari: SafariCheckResult(installed: true, extensionsListing: nil, managedPreferences: nil, searchProvider: "com.google", homePage: "https://apple.com", safariExtensionsOutput: nil, suspicious: false),
            browserProcesses: [],
            suspiciousSummary: []
        ))
    }
    .padding()
}
