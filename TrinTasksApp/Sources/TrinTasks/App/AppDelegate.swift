import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController!
    let store = AppStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.notificationService.requestAuthorization()
        menuBarController = MenuBarController(store: store)
        store.startBackgroundRefresh()
        Task { await store.refresh() }
    }
}
