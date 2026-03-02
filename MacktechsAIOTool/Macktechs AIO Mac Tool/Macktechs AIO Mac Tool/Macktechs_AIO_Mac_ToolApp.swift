import SwiftUI

@main
struct MacktechsAIOMacToolApp: App {
    @StateObject private var diagnosticStore = DiagnosticStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(diagnosticStore)
        }
    }
}
