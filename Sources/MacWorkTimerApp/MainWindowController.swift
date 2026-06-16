import AppKit
import MacWorkTimerCore
import SwiftUI

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private var window: NSWindow?

    func showLogin() {
        guard MainWindowPresentationPolicy.shouldOpenLoginWindow(hasSession: AppModel.shared.currentSession != nil) else {
            hide()
            PetWindowController.shared.show()
            return
        }

        let window = existingOrCreateWindow()
        resizeForCurrentState()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func resizeForCurrentState() {
        guard let window else {
            return
        }

        let hasSession = AppModel.shared.currentSession != nil
        guard !MainWindowPresentationPolicy.shouldHideMainWindow(hasSession: hasSession) else {
            hide()
            return
        }

        let size = Self.contentSize(hasSession: hasSession)

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
                size: Self.contentSize(hasSession: AppModel.shared.currentSession != nil)
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

    private static func contentSize(hasSession: Bool) -> NSSize {
        let size = MainWindowMetrics.contentSize(hasSession: hasSession)
        return NSSize(width: size.width, height: size.height)
    }
}
