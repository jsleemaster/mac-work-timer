import CoreGraphics

public enum FloatingPanelPlacement {
    public static func bottomRightFrame(
        visibleFrame: CGRect,
        panelSize: CGSize,
        margin: CGFloat = 24
    ) -> CGRect {
        guard visibleFrame.width >= panelSize.width + margin * 2,
              visibleFrame.height >= panelSize.height + margin * 2 else {
            return CGRect(origin: visibleFrame.origin, size: panelSize)
        }

        return CGRect(
            x: visibleFrame.maxX - panelSize.width - margin,
            y: visibleFrame.minY + margin,
            width: panelSize.width,
            height: panelSize.height
        )
    }
}
