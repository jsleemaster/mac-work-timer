import XCTest
@testable import MacWorkTimerCore

final class MainWindowMetricsTests: XCTestCase {
    func testActiveSessionWindowUsesCompactHeightWithoutTimerCard() {
        XCTAssertEqual(MainWindowMetrics.contentSize(hasSession: true), WindowSize(width: 430, height: 160))
    }

    func testLoginWindowKeepsWebLoginSize() {
        XCTAssertEqual(MainWindowMetrics.contentSize(hasSession: false), WindowSize(width: 620, height: 560))
    }
}
