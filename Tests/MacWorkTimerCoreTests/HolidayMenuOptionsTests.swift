import XCTest
@testable import MacWorkTimerCore

final class HolidayMenuOptionsTests: XCTestCase {
    private let builder = HolidayMenuOptionsBuilder()

    func testListsMondayThroughFridayOfTheWeekContainingToday() {
        // 2026-08-19 is a Wednesday.
        let options = builder.currentWeekOptions(today: "2026-08-19", holidays: HolidayCalendar())

        XCTAssertEqual(
            options.map(\.workDate),
            ["2026-08-17", "2026-08-18", "2026-08-19", "2026-08-20", "2026-08-21"]
        )
    }

    func testWeekendTodayStillListsThatWeeksWeekdays() {
        // 2026-08-22 is a Saturday; its week still starts on Monday the 17th.
        let options = builder.currentWeekOptions(today: "2026-08-22", holidays: HolidayCalendar())

        XCTAssertEqual(options.first?.workDate, "2026-08-17")
        XCTAssertEqual(options.last?.workDate, "2026-08-21")
        XCTAssertFalse(options.contains { $0.isToday })
    }

    func testSundayBelongsToThePrecedingMondayWeek() {
        // 2026-08-23 is a Sunday: the week starts on Monday, so it closes the 17th's week.
        let options = builder.currentWeekOptions(today: "2026-08-23", holidays: HolidayCalendar())

        XCTAssertEqual(options.first?.workDate, "2026-08-17")
        XCTAssertEqual(options.last?.workDate, "2026-08-21")
    }

    func testLabelsCarryMonthDayAndKoreanWeekday() {
        let options = builder.currentWeekOptions(today: "2026-08-19", holidays: HolidayCalendar())

        XCTAssertEqual(
            options.map(\.label),
            ["8/17 (월)", "8/18 (화)", "8/19 (수) · 오늘", "8/20 (목)", "8/21 (금)"]
        )
    }

    func testMarksTodayAndPastDays() {
        let options = builder.currentWeekOptions(today: "2026-08-19", holidays: HolidayCalendar())
        let byDate = Dictionary(uniqueKeysWithValues: options.map { ($0.workDate, $0) })

        XCTAssertTrue(byDate["2026-08-17"]?.isPast == true)
        XCTAssertFalse(byDate["2026-08-19"]?.isPast == true)
        XCTAssertTrue(byDate["2026-08-19"]?.isToday == true)
        XCTAssertFalse(byDate["2026-08-20"]?.isPast == true)
        XCTAssertFalse(byDate["2026-08-20"]?.isToday == true)
    }

    func testManualHolidayOnAPastDayIsCheckedAndToggleable() {
        let holidays = HolidayCalendar(manualEntries: [HolidayEntry(workDate: "2026-08-17", title: "창립기념일")])
        let options = builder.currentWeekOptions(today: "2026-08-19", holidays: holidays)
        let monday = options.first { $0.workDate == "2026-08-17" }

        XCTAssertEqual(monday?.isHoliday, true)
        XCTAssertEqual(monday?.isLocked, false)
        XCTAssertEqual(monday?.title, "창립기념일")
        XCTAssertEqual(monday?.label, "8/17 (월) · 창립기념일")
    }

    func testGWReportedHolidayIsCheckedButLocked() {
        let holidays = HolidayCalendar(
            manualEntries: [],
            records: [
                WeeklyAttendanceRecord(workDate: "2026-08-18", kind: .holiday, sourceText: "2026-08-18 공휴일")
            ]
        )
        let options = builder.currentWeekOptions(today: "2026-08-19", holidays: holidays)
        let tuesday = options.first { $0.workDate == "2026-08-18" }

        XCTAssertEqual(tuesday?.isHoliday, true)
        XCTAssertEqual(tuesday?.isLocked, true)
        XCTAssertEqual(tuesday?.label, "8/18 (화) · 휴일 (GW)")
    }

    func testTodayLabelKeepsBothTodayMarkerAndHolidayTitle() {
        let holidays = HolidayCalendar(manualEntries: [HolidayEntry(workDate: "2026-08-19", title: "여름휴가")])
        let options = builder.currentWeekOptions(today: "2026-08-19", holidays: holidays)
        let today = options.first { $0.isToday }

        XCTAssertEqual(today?.label, "8/19 (수) · 오늘 · 여름휴가")
    }

    func testMalformedTodayYieldsNoOptions() {
        XCTAssertTrue(builder.currentWeekOptions(today: "not-a-date", holidays: HolidayCalendar()).isEmpty)
    }
}
