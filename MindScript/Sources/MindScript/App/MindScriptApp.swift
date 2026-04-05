import SwiftUI

@main
struct MindScriptApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No window scenes — this is a menubar-only app.
        // All UI is driven from AppDelegate via NSStatusItem.
        Settings {
            EmptyView()
        }
    }
}
