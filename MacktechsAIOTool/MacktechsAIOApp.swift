//
//  MacktechsAIOApp.swift
//  Macktechs AIO Tool
//
//  Main app entry point. Single-window SwiftUI macOS app.
//

import SwiftUI

@main
struct MacktechsAIOApp: App {
    @StateObject private var diagnosticStore = DiagnosticStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(diagnosticStore)
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowTitleDisplayMode(.inline)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
