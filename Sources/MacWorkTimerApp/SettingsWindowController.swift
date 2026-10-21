import AppKit
import MacWorkTimerCore
import SwiftUI

/// Hosts `SettingsView` in a window the status bar menu can open.
///
/// The app runs with `.accessory` activation policy, so it has no application menu and the
/// SwiftUI `Settings` scene's ⌘, binding is unreachable. Without this controller the holiday
/// date picker — the only way to register a holiday for an arbitrary date — could never be
/// opened, which left the today-only menu toggle as the sole holiday control.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        let window = existingOrCreateWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func existingOrCreateWindow() -> NSWindow {
        if let window {
            return window
        }

        let contentView = SettingsView()
            .environmentObject(AppModel.shared)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 380, height: 420)),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "설정"
        window.contentViewController = NSHostingController(rootView: contentView)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        return window
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
