# Macktechs AIO Mac Tool

macOS tools for **Macktechs** — browser health checks, system overview, and (planned) security diagnostics. Runs on **macOS 11 Big Sur or newer** (Intel and Apple Silicon).

---

## Project summary

This repo contains three ways to run browser and system health checks:

| Tool | Description |
|------|-------------|
| **`browser_health_check.sh`** | Standalone zsh script. Writes a timestamped report to the Desktop. Can be run from Terminal or wrapped in Automator/Platypus. |
| **`browser_health_check_app.py`** | Python + tkinter GUI. Choose browsers to scan, view results in tabs, remove extensions/login items, change Safari home/search, save report. |
| **Macktechs AIO Tool (SwiftUI)** | Native macOS app. Sidebar with Overview (hardware/battery), Browser Health (runs the script in-app), and placeholders for System Health and Security. |

All three use the same core checks (hosts, DNS, proxy, LaunchAgents/LaunchDaemons, login items, Chrome/Firefox/Safari extensions and preferences, suspicious-pattern flagging).

---

## Tools in detail

### 1. `browser_health_check.sh` (zsh)

- **What it does:** One-shot scan. Checks macOS version (exits with alert if &lt; 11.0), runs system and browser checks, writes `~/Desktop/browser_health_report_YYYYMMDD_HHMMSS.txt`, shows a “Scan completed” alert.
- **Checks:** `/etc/hosts`, Wi‑Fi DNS and proxy, user/system LaunchAgents and LaunchDaemons, login items, Chrome profiles/extensions/managed prefs, Firefox profiles/extensions/policies, Safari extensions/managed prefs/search/homepage, browser-related processes. Flags suspicious patterns (e.g. known PUPs/adware).
- **How to run:**
  ```bash
  chmod +x browser_health_check.sh
  ./browser_health_check.sh
  ```
- **Use case:** Terminal, cron, or wrap in an Automator/Platypus app.

---

### 2. `browser_health_check_app.py` (Python + tkinter)

- **What it does:** GUI to select browsers (Chrome, Firefox, Safari), run a scan, then view and act on results in tabbed panels.
- **Features:**
  - **System:** Hosts, DNS, proxy, LaunchAgents/LaunchDaemons, login items — with “Reveal in Finder” and **Remove** for login items.
  - **Chrome / Firefox / Safari:** Profiles (Reveal), **Extensions** with **Remove** per extension, managed prefs (read-only).
  - **Safari:** **Change…** for default home page and search provider.
  - **Summary:** Suspicious flags and Macktechs footer.
  - **Save report to Desktop** (same style as the shell script).
- **How to run:**
  ```bash
  python3 browser_health_check_app.py
  ```
- **Requirements:** Python 3 with tkinter (included with macOS Python). For extension removal, quit the browser first, then re-scan after removing.

---

### 3. Macktechs AIO Tool (SwiftUI macOS app)

- **What it does:** Single-window app with a sidebar (Malwarebytes-style): **Overview**, **Browser Health**, **System Health**, **Security & Malware**.
- **Overview:** Mac model identifier (and optional marketing name), CPU, RAM (GB), SSD total/free (GB), battery cycle count and health % (when available).
- **Browser Health:** “Run Scan” runs the bundled `browser_health_check.sh` and shows its output in a scrollable, monospaced log in the same window (no extra windows).
- **System Health / Security & Malware:** Placeholders for future features.
- **How to build and run:** See **[MacktechsAIOTool/README.md](MacktechsAIOTool/README.md)** for Xcode setup (new macOS App project, add Swift sources and `Info.plist`, add `browser_health_check.sh` to Copy Bundle Resources).

---

## Support

- **Report / help:** [https://fix.macktechs.com](https://fix.macktechs.com)  
- **Email:** support@macktechs.com — you can send a saved report file for interpretation.

---

## Repo layout (main items)

```
macktechs-aio-mac-tool/
├── README.md                    ← this file
├── browser_health_check.sh      ← standalone script
├── browser_health_check_app.py  ← Python GUI
└── MacktechsAIOTool/            ← SwiftUI macOS app
    ├── README.md                ← Xcode setup
    ├── Info.plist
    ├── MacktechsAIOApp.swift
    ├── ContentView.swift
    ├── Views/
    │   ├── OverviewView.swift
    │   ├── BrowserHealthView.swift
    │   ├── SystemHealthView.swift
    │   └── SecurityView.swift
    ├── Utilities/
    │   ├── MacInfo.swift
    │   ├── BatteryInfo.swift
    │   └── ProcessRunner.swift
    └── Resources/
        └── browser_health_check.sh  ← copy used by the app bundle
```
