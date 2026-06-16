import XCTest
@testable import MacWorkTimerCore

final class PetPanelMetricsTests: XCTestCase {
    func testTwoLineLabelLeavesBottomMarginForLocalEvolutionSprite() {
        XCTAssertLessThanOrEqual(
            PetPanelMetrics.localSpriteVisualBottom(hasLeaveTime: true),
            PetPanelMetrics.height - PetPanelMetrics.minimumBottomMargin
        )
    }

    func testTwoLineLabelLeavesComfortableBottomClearanceForLocalEvolutionSprite() {
        let comfortableBottomClearance = 24.0

        XCTAssertGreaterThanOrEqual(
            PetPanelMetrics.height - PetPanelMetrics.localSpriteVisualBottom(hasLeaveTime: true),
            comfortableBottomClearance
        )
    }

    func testSingleLineLabelLeavesBottomMarginForLocalEvolutionSprite() {
        XCTAssertLessThanOrEqual(
            PetPanelMetrics.localSpriteVisualBottom(hasLeaveTime: false),
            PetPanelMetrics.height - PetPanelMetrics.minimumBottomMargin
        )
    }

    func testLabelWidthCanFitAgentUsageLineWithoutHeavyShrinking() {
        XCTAssertGreaterThanOrEqual(PetPanelMetrics.labelMaxWidth, 188)
        XCTAssertGreaterThanOrEqual(PetPanelMetrics.width, PetPanelMetrics.labelMaxWidth)
    }

    func testPanelCanFitPetAndTwoAgentUsageColumns() {
        XCTAssertEqual(PetPanelMetrics.agentUsageGridColumnCount, 2)

        let minimumTwoColumnUsageWidth =
            PetPanelMetrics.agentUsageGridColumnWidth * Double(PetPanelMetrics.agentUsageGridColumnCount)
            + PetPanelMetrics.agentUsageGridSpacing
        let minimumComposedWidth = PetPanelMetrics.localSpriteWidth + minimumTwoColumnUsageWidth + 18.0

        XCTAssertGreaterThanOrEqual(PetPanelMetrics.width, minimumComposedWidth)
    }

    func testAgentUsageCardPrioritizesReadableTextAndMeter() {
        XCTAssertGreaterThanOrEqual(PetPanelMetrics.agentUsagePrimaryFontSize, 15)
        XCTAssertGreaterThanOrEqual(PetPanelMetrics.agentUsageSecondaryFontSize, 10)
        XCTAssertGreaterThanOrEqual(PetPanelMetrics.agentUsageMeterHeight, 7)
        XCTAssertGreaterThanOrEqual(
            PetPanelMetrics.agentUsageGridColumnWidth,
            PetPanelMetrics.agentUsagePrimaryFontSize * 4
        )
    }

    func testAgentUsageCardsDoNotSitOnPanelBottomEdge() {
        let comfortableBottomClearance = 24.0
        let estimatedTallCardHeight = 64.0
        let visualBottom =
            PetPanelMetrics.agentUsageGridOffsetY
            + estimatedTallCardHeight
            + PetPanelMetrics.maxFloatOffset

        XCTAssertGreaterThanOrEqual(
            PetPanelMetrics.height - visualBottom,
            comfortableBottomClearance
        )
    }
}
