import SwiftUI

@main
struct TrinTasksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No default window — the app lives in the menu bar only
        Settings { EmptyView() }
    }
}
