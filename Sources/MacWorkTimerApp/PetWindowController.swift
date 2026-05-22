import AppKit
import MacWorkTimerCore
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
        let frame = FloatingPanelPlacement.bottomRightFrame(
            visibleFrame: placementVisibleFrame(),
            panelSize: size
        )

        return NSRect(
            x: frame.minX,
            y: frame.minY,
            width: frame.width,
            height: frame.height
        )
    }

    private func placementVisibleFrame() -> NSRect {
        (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
