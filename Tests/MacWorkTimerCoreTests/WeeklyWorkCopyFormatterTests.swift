import XCTest
@testable import MacWorkTimerCore

final class WeeklyWorkCopyFormatterTests: XCTestCase {
    func testPositiveBalanceUsesFriendlyFreeTimeCopy() {
        XCTAssertEqual(WeeklyWorkCopyFormatter.balanceLine(23 * 60), "이번 주 여유 +23분")
    }

    func testZeroBalanceUsesFriendlyExactCopy() {
        XCTAssertEqual(WeeklyWorkCopyFormatter.balanceLine(0), "이번 주 딱 맞아요")
    }

    func testNegativeBalanceUsesFriendlyShortageCopy() {
        XCTAssertEqual(WeeklyWorkCopyFormatter.balanceLine(-14 * 60), "이번 주 부족 14분")
    }

    func testHourAndMinuteBalanceRemainsCompact() {
        XCTAssertEqual(WeeklyWorkCopyFormatter.balanceLine(72 * 60), "이번 주 여유 +1시간 12분")
    }

    func testPositiveBalanceSplitsIntoAlignedFriendlyRow() {
        let copy = WeeklyWorkCopyFormatter.balanceCopy(23 * 60)

        XCTAssertEqual(copy.label, "이번 주 여유")
        XCTAssertEqual(copy.value, "+23분")
    }

    func testNegativeBalanceSplitsIntoShortageRow() {
        let copy = WeeklyWorkCopyFormatter.balanceCopy(-14 * 60)

        XCTAssertEqual(copy.label, "이번 주 부족")
        XCTAssertEqual(copy.value, "14분")
    }
}
