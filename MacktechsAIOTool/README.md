# Macktechs AIO Mac Tool (SwiftUI macOS)

**This is the primary and only shipping product.** Single-window macOS app with sidebar: Overview, Browser Health Check, System Health, and read-only diagnostics (Startup Items, Installed Applications, Crash Logs, Network Diagnostics, Security Scan). All operations are **read-only** (detection, reporting, analysis, display only).

Builds to one .app: **Macktechs AIO Mac Tool.app**.

## Features

- **Overview** — Hardware (model, CPU, RAM, disk) and battery (cycles, health %).
- **Browser Health Check** — Runs bundled `browser_health_check.sh`, shows output in-app. Use **Run Browser Health Scan** to run the script.
- **Startup Items** — User/System LaunchAgents, LaunchDaemons, Login Items (name, path, signature, notes).
- **Installed Applications** — Apps from /Applications, /Applications/Utilities, ~/Applications (name, version, bundle ID, signed, arch, size).
- **Crash Logs** — Recent DiagnosticReports/CrashReporter logs, summary, most frequent process.
- **Network Diagnostics** — Interface, IP, router, DNS, proxy, Wi‑Fi (SSID, RSSI), ping (1.1.1.1, 8.8.8.8).
- **Security Scan** — Configuration profiles, SIP, Gatekeeper, XProtect/MRT versions, /etc/hosts, suspicious startup items.
- **Run Full Diagnostic** — Runs all scanners and the browser script, writes a timestamped report folder to **~/Documents/Macktechs AIO Mac Tool Reports/<timestamp>/** with `report.json` and `report.html`.
- **Export / Email Report…** — Opens the share sheet so you can attach the latest report (Mail, etc.). Run Full Diagnostic first to generate a report.

## Xcode setup

1. **New project:** File → New → Project → **macOS** → **App**.  
   - Product Name: `Macktechs AIO Mac Tool`  
   - Team: your team  
   - Organization Identifier: `com.macktechs`  
   - Bundle Identifier: `com.macktechs.aiomac.tool`  
   - Interface: **SwiftUI**, Language: **Swift**, minimum deployment **macOS 11.0**.

2. **Replace/use these sources:**  
   - Delete the default `ContentView.swift` and `*App.swift` if you want to use this layout.  
   - Add all `.swift` files from this folder (and `Utilities/`, `Views/` subfolders) to the app target.  
   - Set the app entry point to **MacktechsAIOMacToolApp** (main struct in `MacktechsAIOMacToolApp.swift`).

3. **Info.plist:**  
   - Either set the target’s **Info** tab (or custom plist) so that **Bundle display name** = “Macktechs AIO Mac Tool” and **Bundle identifier** = `com.macktechs.aiomac.tool`, or  
   - Add this repo’s `Info.plist` to the target and ensure it’s used as the target’s Info.plist.

4. **Bundle the script:**  
   - Add `Resources/browser_health_check.sh` to the target (drag into the project, or add via **File → Add Files**).  
   - In the target’s **Build Phases**, add the script to **Copy Bundle Resources** so it ships inside the app.  
   - The app looks it up with `Bundle.main.url(forResource: "browser_health_check", withExtension: "sh")`.

5. **Add all Phase Two files** (if not already added):  
   - **Views:** `StartupItemsView.swift`, `InstalledAppsView.swift`, `CrashLogsView.swift`, `NetworkDiagnosticsView.swift`, `SecurityScanView.swift`.  
   - **Utilities:** `StartupScanner.swift`, `InstalledAppsScanner.swift`, `CrashLogScanner.swift`, `NetworkScanner.swift`, `SecurityScanner.swift`, `DiagnosticReport.swift`, `ReportGenerator.swift`, `DiagnosticStore.swift`, `BrowserHealthRunner.swift`.  
   Ensure they are in the app target (no extra bundle resources needed beyond `browser_health_check.sh`).

6. Build and run. Only the main SwiftUI window should appear. Use **Run Browser Health Scan** in the Browser Health Check tab to run the script; use **Run Full Diagnostic** to generate a full report; use **Export / Email Report…** to share it (no email is sent automatically).
