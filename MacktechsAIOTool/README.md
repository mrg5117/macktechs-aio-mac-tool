# Macktechs AIO Tool (SwiftUI macOS)

Single-window macOS app with sidebar: Overview, Browser Health, System Health, Security & Malware.

## Xcode setup

1. **New project:** File → New → Project → **macOS** → **App**.  
   - Product Name: `Macktechs AIO Tool`  
   - Team: your team  
   - Organization Identifier: `com.macktechs`  
   - Bundle Identifier: `com.macktechs.aiotool`  
   - Interface: **SwiftUI**, Language: **Swift**, minimum deployment **macOS 11.0**.

2. **Replace/use these sources:**  
   - Delete the default `ContentView.swift` and `*App.swift` if you want to use this layout.  
   - Add all `.swift` files from this folder (and `Utilities/`, `Views/` subfolders) to the app target.  
   - Set the app entry point to **MacktechsAIOApp** (main struct in `MacktechsAIOApp.swift`).

3. **Info.plist:**  
   - Either set the target’s **Info** tab (or custom plist) so that **Bundle display name** = “Macktechs AIO Tool” and **Bundle identifier** = `com.macktechs.aiotool`, or  
   - Add this repo’s `Info.plist` to the target and ensure it’s used as the target’s Info.plist.

4. **Bundle the script:**  
   - Add `Resources/browser_health_check.sh` to the target (drag into the project, or add via **File → Add Files**).  
   - In the target’s **Build Phases**, add the script to **Copy Bundle Resources** so it ships inside the app.  
   - The app looks it up with `Bundle.main.url(forResource: "browser_health_check", withExtension: "sh")`.

5. Build and run. Only the main SwiftUI window should appear; Browser Health runs the script inside the app and shows output in the same window.
