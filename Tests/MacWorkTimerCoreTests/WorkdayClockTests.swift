import XCTest
@testable import MacWorkTimerCore

final class WorkdayClockTests: XCTestCase {
    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    func testMondayFirstStartCreatesNineHourTargetIncludingLunch() throws {
        let clock = WorkdayClock(timeZone: seoul)
        let start = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: seoul, year: 2026, month: 5, day: 18, hour: 9, minute: 13).date)

        let session = clock.session(for: start, existing: nil)

        XCTAssertEqual(session?.workStartAt, start)
        XCTAssertEqual(session?.targetAt, start.addingTimeInterval(9 * 60 * 60))
        XCTAssertFalse(session?.isWeekend ?? true)
    }

    func testWeekendDoesNotStartSession() throws {
        let clock = WorkdayClock(timeZone: seoul)
        let saturday = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: seoul, year: 2026, month: 5, day: 16, hour: 9).date)

        XCTAssertNil(clock.session(for: saturday, existing: nil))
    }

    func testHolidayDoesNotStartSession() throws {
        let clock = WorkdayClock(timeZone: seoul)
        let monday = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: seoul, year: 2026, month: 5, day: 18, hour: 9).date)

        XCTAssertNil(clock.session(for: monday, existing: nil, holidayDates: ["2026-05-18"]))
    }

    func testHolidayDiscardsAStoredSessionFromThatDay() throws {
        let clock = WorkdayClock(timeZone: seoul)
        let monday = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: seoul, year: 2026, month: 5, day: 18, hour: 9).date)
        let later = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: seoul, year: 2026, month: 5, day: 18, hour: 14).date)
        let existing = WorkSession(workDate: clock.workDate(for: monday), workStartAt: monday)

        XCTAssertNil(clock.session(for: later, existing: existing, holidayDates: ["2026-05-18"]))
    }

    func testUnrelatedHolidayDoesNotBlockToday() throws {
        let clock = WorkdayClock(timeZone: seoul)
        let monday = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: seoul, year: 2026, month: 5, day: 18, hour: 9).date)

        XCTAssertNotNil(clock.session(for: monday, existing: nil, holidayDates: ["2026-05-19"]))
    }

    func testSameDayKeepsExistingStart() throws {
        let clock = WorkdayClock(timeZone: seoul)
        let firstStart = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: seoul, year: 2026, month: 5, day: 19, hour: 8, minute: 52).date)
        let later = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: seoul, year: 2026, month: 5, day: 19, hour: 10, minute: 30).date)
        let existing = WorkSession(workDate: clock.workDate(for: firstStart), workStartAt: firstStart)

        let session = clock.session(for: later, existing: existing)

        XCTAssertEqual(session?.workStartAt, firstStart)
        XCTAssertEqual(session?.targetAt, firstStart.addingTimeInterval(9 * 60 * 60))
    }

    func testDifferentDayStartsNewSession() throws {
        let clock = WorkdayClock(timeZone: seoul)
        let previous = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: seoul, year: 2026, month: 5, day: 18, hour: 9).date)
        let next = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: seoul, year: 2026, month: 5, day: 19, hour: 9, minute: 10).date)
        let existing = WorkSession(workDate: clock.workDate(for: previous), workStartAt: previous)

        let session = clock.session(for: next, existing: existing)

        XCTAssertEqual(session?.workStartAt, next)
        XCTAssertEqual(session?.workDate, clock.workDate(for: next))
    }

    func testRemainingTimeStopsAtZeroAfterTarget() throws {
        let clock = WorkdayClock(timeZone: seoul)
        let start = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: seoul, year: 2026, month: 5, day: 19, hour: 9).date)
        let session = WorkSession(workDate: clock.workDate(for: start), workStartAt: start)
        let afterTarget = start.addingTimeInterval(9 * 60 * 60 + 3)

        XCTAssertEqual(clock.remainingTime(for: session, at: afterTarget), 0)
    }
}
