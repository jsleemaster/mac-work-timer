import XCTest
@testable import MacWorkTimerCore

final class HolidayCalendarTests: XCTestCase {
    func testManualEntryMarksHoliday() {
        let calendar = HolidayCalendar(manualEntries: [HolidayEntry(workDate: "2026-08-17", title: "창립기념일")])

        XCTAssertTrue(calendar.isHoliday("2026-08-17"))
        XCTAssertFalse(calendar.isHoliday("2026-08-18"))
    }

    func testWeeklyRecordMarksHoliday() {
        let calendar = HolidayCalendar(
            manualEntries: [],
            records: [
                WeeklyAttendanceRecord(workDate: "2026-08-17", kind: .holiday, sourceText: "2026-08-17 공휴일")
            ]
        )

        XCTAssertTrue(calendar.isHoliday("2026-08-17"))
    }

    func testCreditedLeaveIsNotHoliday() {
        let calendar = HolidayCalendar(
            manualEntries: [],
            records: [
                WeeklyAttendanceRecord(
                    workDate: "2026-08-17",
                    kind: .creditedLeave,
                    creditedDuration: 8 * 60 * 60,
                    sourceText: "2026-08-17 연차"
                )
            ]
        )

        XCTAssertFalse(calendar.isHoliday("2026-08-17"))
    }

    func testOverlappingSourcesStayASingleHoliday() {
        let calendar = HolidayCalendar(
            manualEntries: [HolidayEntry(workDate: "2026-08-17", title: "광복절 대체")],
            records: [
                WeeklyAttendanceRecord(workDate: "2026-08-17", kind: .holiday, sourceText: "2026-08-17 대체공휴일")
            ]
        )

        XCTAssertEqual(calendar.holidayDates, ["2026-08-17"])
    }

    func testTitleFallsBackToDefaultForRecordDerivedHoliday() {
        let calendar = HolidayCalendar(
            manualEntries: [],
            records: [
                WeeklyAttendanceRecord(workDate: "2026-08-17", kind: .holiday, sourceText: "2026-08-17 대체공휴일")
            ]
        )

        XCTAssertEqual(calendar.title(for: "2026-08-17"), HolidayEntry.defaultTitle)
    }

    func testManualTitleWinsOverRecordDerivedHoliday() {
        let calendar = HolidayCalendar(
            manualEntries: [HolidayEntry(workDate: "2026-08-17", title: "창립기념일")],
            records: [
                WeeklyAttendanceRecord(workDate: "2026-08-17", kind: .holiday, sourceText: "2026-08-17 대체공휴일")
            ]
        )

        XCTAssertEqual(calendar.title(for: "2026-08-17"), "창립기념일")
    }

    func testAppStateHidesTheSessionOnAManualHoliday() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let start = try XCTUnwrap(DateComponents(
            calendar: clock.calendar,
            timeZone: clock.calendar.timeZone,
            year: 2026,
            month: 6,
            day: 10,
            hour: 9,
            minute: 15
        ).date)
        var state = AppState(
            todaySession: nil,
            gwStatus: .attendance(AttendanceRecord(workDate: "2026-06-10", checkInAt: start, sourceText: "출근")),
            notificationSentForDate: nil
        )

        XCTAssertNotNil(state.currentSession(on: start, clock: clock))

        state.holidays = [HolidayEntry(workDate: "2026-06-10", title: "창립기념일")]

        XCTAssertNil(state.currentSession(on: start, clock: clock))
    }

    func testAppStateHidesTheSessionOnAGWReportedHoliday() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let start = try XCTUnwrap(DateComponents(
            calendar: clock.calendar,
            timeZone: clock.calendar.timeZone,
            year: 2026,
            month: 6,
            day: 10,
            hour: 9,
            minute: 15
        ).date)
        let state = AppState(
            todaySession: nil,
            gwStatus: .attendance(AttendanceRecord(workDate: "2026-06-10", checkInAt: start, sourceText: "출근")),
            notificationSentForDate: nil,
            weeklyAttendanceCache: WeeklyAttendanceCache(
                weekStart: "2026-06-08",
                fetchedAt: start,
                records: [WeeklyAttendanceRecord(workDate: "2026-06-10", kind: .holiday, sourceText: "2026-06-10 공휴일")]
            )
        )

        XCTAssertNil(state.currentSession(on: start, clock: clock))
    }

    func testManualEntrySourceIsReportedForToggleAffordance() {
        let calendar = HolidayCalendar(
            manualEntries: [HolidayEntry(workDate: "2026-08-17", title: "창립기념일")],
            records: [
                WeeklyAttendanceRecord(workDate: "2026-08-18", kind: .holiday, sourceText: "2026-08-18 공휴일")
            ]
        )

        XCTAssertTrue(calendar.isManualHoliday("2026-08-17"))
        XCTAssertFalse(calendar.isManualHoliday("2026-08-18"))
        XCTAssertTrue(calendar.isHoliday("2026-08-18"))
    }
}
