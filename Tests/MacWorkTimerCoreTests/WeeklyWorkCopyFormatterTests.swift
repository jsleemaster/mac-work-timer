import XCTest
@testable import MacWorkTimerCore

final class WeeklyWorkCopyFormatterTests: XCTestCase {
    func testLoginRecoveryPromptUsesFriendlyActionCopy() {
        XCTAssertEqual(WeeklyWorkCopyFormatter.loginRecoveryPrompt, "주간 기록 연결하기")
    }

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

    func testOvertimeCopyKeepsHolidayWorkSeparateFromFlex() {
        let copy = WeeklyWorkCopyFormatter.overtimeCopy(8 * 60 * 60)

        XCTAssertEqual(copy?.label, "이번 주 초과근무")
        XCTAssertEqual(copy?.value, "+8시간")
    }

    func testOvertimeCopyIsHiddenWhenThereIsNoHolidayWork() {
        XCTAssertNil(WeeklyWorkCopyFormatter.overtimeCopy(0))
        XCTAssertNil(WeeklyWorkCopyFormatter.overtimeCopy(30))
    }

    func testOvertimeLineMatchesTheSplitCopy() {
        XCTAssertEqual(WeeklyWorkCopyFormatter.overtimeLine(90 * 60), "이번 주 초과근무 +1시간 30분")
        XCTAssertNil(WeeklyWorkCopyFormatter.overtimeLine(0))
    }

    func testHolidayCountLineSummarizesExcludedDays() {
        XCTAssertNil(WeeklyWorkCopyFormatter.holidayLine([]))
        XCTAssertEqual(WeeklyWorkCopyFormatter.holidayLine(["2026-08-17"]), "휴일 1일 제외")
        XCTAssertEqual(WeeklyWorkCopyFormatter.holidayLine(["2026-08-17", "2026-08-18"]), "휴일 2일 제외")
    }
}
