import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController!
    let store = AppStore()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.notificationService.requestAuthorization()
        menuBarController = MenuBarController(store: store)
        store.startBackgroundRefresh()
        Task { await store.refresh() }
    }
}
