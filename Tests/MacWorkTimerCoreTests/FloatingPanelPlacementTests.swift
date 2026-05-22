import CoreGraphics
import XCTest
@testable import MacWorkTimerCore

final class FloatingPanelPlacementTests: XCTestCase {
    func testBottomRightPlacementStaysInsideVisibleFrame() {
        let visibleFrame = CGRect(x: -1_280, y: -900, width: 1_280, height: 860)
        let panelSize = CGSize(width: 108, height: 124)

        let frame = FloatingPanelPlacement.bottomRightFrame(
            visibleFrame: visibleFrame,
            panelSize: panelSize,
            margin: 24
        )

        XCTAssertGreaterThanOrEqual(frame.minX, visibleFrame.minX)
        XCTAssertGreaterThanOrEqual(frame.minY, visibleFrame.minY)
        XCTAssertLessThanOrEqual(frame.maxX, visibleFrame.maxX)
        XCTAssertLessThanOrEqual(frame.maxY, visibleFrame.maxY)
        XCTAssertEqual(frame.maxX, visibleFrame.maxX - 24)
        XCTAssertEqual(frame.minY, visibleFrame.minY + 24)
    }

    func testTinyVisibleFrameFallsBackToOriginWithoutEscaping() {
        let visibleFrame = CGRect(x: 10, y: 20, width: 80, height: 90)
        let panelSize = CGSize(width: 108, height: 124)

        let frame = FloatingPanelPlacement.bottomRightFrame(
            visibleFrame: visibleFrame,
            panelSize: panelSize,
            margin: 24
        )

        XCTAssertEqual(frame.origin.x, visibleFrame.minX)
        XCTAssertEqual(frame.origin.y, visibleFrame.minY)
        XCTAssertEqual(frame.size, panelSize)
    }
}
