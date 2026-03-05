import SwiftUI

@main
struct TFTAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar app - pas de fenêtre principale
        Settings {
            EmptyView()
        }
    }
}
