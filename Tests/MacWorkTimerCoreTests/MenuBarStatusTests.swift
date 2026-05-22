import XCTest
@testable import MacWorkTimerCore

final class MenuBarStatusTests: XCTestCase {
    func testRemainingTitleUsesHoursWhenMoreThanOneHourRemains() {
        XCTAssertEqual(MenuBarStatusFormatter.title(remaining: 5 * 3600 + 12 * 60), "5h 12m")
        XCTAssertEqual(MenuBarStatusFormatter.title(remaining: 2 * 3600), "2h 0m")
    }

    func testRemainingTitleUsesMinutesBelowOneHour() {
        XCTAssertEqual(MenuBarStatusFormatter.title(remaining: 42 * 60 + 12), "42m")
    }

    func testRemainingTitleUsesSecondsInFinalMinute() {
        XCTAssertEqual(MenuBarStatusFormatter.title(remaining: 38), "38s")
    }

    func testRemainingTitleShowsDoneAtTarget() {
        XCTAssertEqual(MenuBarStatusFormatter.title(remaining: 0), "퇴근")
    }

    func testUrgencyMovesFromWhiteTowardRed() {
        XCTAssertEqual(MenuBarStatusFormatter.urgency(progress: 0), 0)
        XCTAssertEqual(MenuBarStatusFormatter.urgency(progress: 0.5), 0.5)
        XCTAssertEqual(MenuBarStatusFormatter.urgency(progress: 1), 1)
    }
}
