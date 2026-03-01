# Macktechs AIO Mac Tool

macOS diagnostic suite for **Macktechs** — browser health checks, system overview, and security diagnostics. Runs on **macOS 11 Big Sur or newer** (Intel and Apple Silicon).

---

## Primary product: SwiftUI macOS app

**The main product is the SwiftUI app.** It is the single unified Macktechs diagnostic tool.

| What | Description |
|------|-------------|
| **Macktechs AIO Mac Tool.app** | Native macOS app (SwiftUI). Sidebar: Overview, **Browser Health Check**, System Health, Startup Items, Installed Applications, Crash Logs, Network Diagnostics, Security Scan. Runs the bundled `browser_health_check.sh` from the **Browser Health Check** tab via **Run Browser Health Scan**. Read-only diagnostics; full report export (JSON + HTML) to ~/Documents/Macktechs AIO Mac Tool Reports/. |

**How to build and run:** Open the SwiftUI project in **MacktechsAIOTool/** and follow **[MacktechsAIOTool/README.md](MacktechsAIOTool/README.md)** for Xcode setup. Build produces **Macktechs AIO Mac Tool.app**.

---

## Auxiliary / supporting files (not the main app)

These are **not** separate shipping products. The shell script is used by the SwiftUI app; the Python app and any old .app bundle are optional/legacy.

| File / folder | Role |
|---------------|------|
| **browser_health_check.sh** | Zsh script that performs browser/system checks. **Bundled inside the SwiftUI app** at `MacktechsAIOTool/Resources/browser_health_check.sh` and run by the app when you tap **Run Browser Health Scan**. Can also be run standalone from Terminal or wrapped in Automator/Platypus. |
| **browser_health_check_app.py** | Python + tkinter GUI (standalone). Auxiliary; the SwiftUI app is the primary GUI. |
| **Browser Health Check App.app** | Old compiled app bundle, if present. Can be removed; the SwiftUI app replaces it. |

---

## Repo layout (main items)

```
macktechs-aio-mac-tool/
├── README.md                         ← this file
├── browser_health_check.sh           ← script (also copied into app bundle)
├── browser_health_check_app.py       ← auxiliary Python GUI
├── MacktechsAIOTool/                 ← SwiftUI app (main Xcode project)
│   ├── README.md                     ← Xcode setup
│   ├── Info.plist
│   ├── MacktechsAIOMacToolApp.swift  ← @main app entry
│   ├── ContentView.swift
│   ├── Views/
│   │   ├── OverviewView.swift
│   │   ├── BrowserHealthView.swift   ← Browser Health Check tab
│   │   ├── SystemHealthView.swift
│   │   ├── SecurityScanView.swift
│   │   └── …
│   ├── Utilities/
│   │   ├── BrowserHealthRunner.swift ← runs bundled script
│   │   ├── ProcessRunner.swift
│   │   ├── MacInfo.swift
│   │   └── …
│   └── Resources/
│       └── browser_health_check.sh   ← bundled with the app
```

---

## Support

- **Report / help:** [https://fix.macktechs.com](https://fix.macktechs.com)  
- **Email:** support@macktechs.com — you can send a saved report file for interpretation.
