import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        StatusBarController.shared.start()
        showAppSurfaces()
        DispatchQueue.main.async {
            self.showAppSurfaces()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showAppSurfaces()
        return true
    }

    private func showAppSurfaces() {
        MainWindowController.shared.show()
        PetWindowController.shared.show()
    }
}
