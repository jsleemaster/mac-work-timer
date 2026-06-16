import XCTest
@testable import MacWorkTimerCore

final class WorkdayModeTests: XCTestCase {
    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    func testFullDayUsesNineHourWallClockDuration() {
        XCTAssertEqual(WorkdayMode.fullDay.duration, 9 * 60 * 60)
    }

    func testHalfDayModesUseFourWorkingHoursPlusLunch() {
        XCTAssertEqual(WorkdayMode.morningHalfDay.duration, 5 * 60 * 60)
        XCTAssertEqual(WorkdayMode.afternoonHalfDay.duration, 5 * 60 * 60)
    }

    func testSessionTargetUsesSelectedModeDuration() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoul
        let start = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: seoul, year: 2026, month: 6, day: 10, hour: 9, minute: 15).date)
        let session = WorkSession(workDate: "2026-06-10", workStartAt: start, workdayMode: .afternoonHalfDay)

        XCTAssertEqual(session.targetAt, start.addingTimeInterval(5 * 60 * 60))
    }

    func testCurrentSessionAppliesTodayModeSelectionToAttendanceRecord() throws {
        let clock = WorkdayClock(timeZone: seoul)
        let start = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: seoul, year: 2026, month: 6, day: 10, hour: 9, minute: 15).date)
        let state = AppState(
            todaySession: nil,
            gwStatus: .attendance(AttendanceRecord(workDate: "2026-06-10", checkInAt: start, sourceText: "출근 2026.06.10 09:15:00")),
            notificationSentForDate: nil,
            workdayModeSelection: WorkdayModeSelection(workDate: "2026-06-10", mode: .afternoonHalfDay)
        )

        XCTAssertEqual(state.currentSession(on: start, clock: clock)?.workdayMode, .afternoonHalfDay)
        XCTAssertEqual(state.currentSession(on: start, clock: clock)?.targetAt, start.addingTimeInterval(5 * 60 * 60))
    }

    func testModeSelectionExpiresOnDifferentWorkDate() throws {
        let clock = WorkdayClock(timeZone: seoul)
        let start = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: seoul, year: 2026, month: 6, day: 11, hour: 9).date)
        let state = AppState(
            todaySession: WorkSession(workDate: "2026-06-11", workStartAt: start),
            gwStatus: .notConfigured,
            notificationSentForDate: nil,
            workdayModeSelection: WorkdayModeSelection(workDate: "2026-06-10", mode: .morningHalfDay)
        )

        XCTAssertEqual(state.currentSession(on: start, clock: clock)?.workdayMode, .fullDay)
    }
}
