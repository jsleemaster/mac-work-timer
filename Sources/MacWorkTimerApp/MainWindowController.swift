import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private var window: NSWindow?

    func show() {
        let window = existingOrCreateWindow()
        resizeForCurrentState()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func resizeForCurrentState() {
        guard let window else {
            return
        }

        let size = AppModel.shared.currentSession == nil
            ? NSSize(width: 620, height: 560)
            : NSSize(width: 430, height: 280)

        guard window.contentView?.frame.size != size else {
            return
        }

        window.setContentSize(size)
    }

    private func existingOrCreateWindow() -> NSWindow {
        if let window {
            return window
        }

        let contentView = ContentView()
            .environmentObject(AppModel.shared)

        let window = NSWindow(
            contentRect: NSRect(
                origin: .zero,
                size: AppModel.shared.currentSession == nil
                    ? NSSize(width: 620, height: 560)
                    : NSSize(width: 430, height: 280)
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mac Work Timer"
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
