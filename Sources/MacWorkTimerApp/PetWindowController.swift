import AppKit
import SwiftUI

@MainActor
final class PetWindowController {
    static let shared = PetWindowController()

    private let size = NSSize(width: 108, height: 124)
    private var panel: NSPanel?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show() {
        revealNearMouse()
    }

    func revealNearMouse() {
        let panel = existingOrCreatePanel()
        panel.setFrame(defaultFrame(), display: true, animate: false)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggleVisibility() {
        isVisible ? hide() : show()
    }

    private func existingOrCreatePanel() -> NSPanel {
        if let panel {
            return panel
        }

        let panel = NSPanel(
            contentRect: defaultFrame(),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.contentViewController = NSHostingController(
            rootView: WorkPetView()
                .environmentObject(AppModel.shared)
        )
        self.panel = panel
        return panel
    }

    private func defaultFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let visibleFrame = placementVisibleFrame(for: mouseLocation)
        let x = min(
            max(mouseLocation.x + 18, visibleFrame.minX + 8),
            visibleFrame.maxX - size.width - 8
        )
        let y = min(
            max(mouseLocation.y - size.height - 18, visibleFrame.minY + 8),
            visibleFrame.maxY - size.height - 8
        )

        return NSRect(
            x: x,
            y: y,
            width: size.width,
            height: size.height
        )
    }

    private func placementVisibleFrame(for mouseLocation: NSPoint) -> NSRect {
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return screen.visibleFrame
        }

        return (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
