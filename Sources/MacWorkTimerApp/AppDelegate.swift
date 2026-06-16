import AppKit
import MacWorkTimerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        StatusBarController.shared.start()
        showAppSurfaces()
        DispatchQueue.main.async {
            self.showAppSurfaces()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainWindowController.shared.showLogin()
        PetWindowController.shared.show()
        return true
    }

    private func showAppSurfaces() {
        if MainWindowPresentationPolicy.shouldShowMainWindowOnLaunch {
            MainWindowController.shared.showLogin()
        }
        PetWindowController.shared.show()
    }
}
