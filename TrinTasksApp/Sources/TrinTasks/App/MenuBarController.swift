import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private let store: AppStore

    init(store: AppStore) {
        self.store = store
        setupStatusItem()
        setupPanel()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let iconURL = Bundle.main.url(forResource: "icon", withExtension: "png"),
               let img = NSImage(contentsOf: iconURL) {
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = true
                button.image = img
            } else {
                button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "TrinTasks")
            }
            button.action = #selector(togglePanel)
            button.target = self
        }
    }

    private func setupPanel() {
        let contentView = ContentView()
            .environmentObject(store)
            .environmentObject(store.themeManager)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 660),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: contentView)
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            positionPanelBelowStatusItem()
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func positionPanelBelowStatusItem() {
        guard let button = statusItem.button,
              let screen = NSScreen.main else { return }
        let buttonRect = button.window?.convertToScreen(button.frame) ?? .zero
        let panelSize = panel.frame.size
        let x = buttonRect.midX - panelSize.width / 2
        let y = buttonRect.minY - panelSize.height - 4
        let origin = NSPoint(
            x: max(screen.visibleFrame.minX, min(x, screen.visibleFrame.maxX - panelSize.width)),
            y: max(screen.visibleFrame.minY, y)
        )
        panel.setFrameOrigin(origin)
    }
}
