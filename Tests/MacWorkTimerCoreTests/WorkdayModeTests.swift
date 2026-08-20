import XCTest
@testable import MacWorkTimerCore

final class WorkdayModeTests: XCTestCase {
    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    private func session(startingAt hour: Int, minute: Int = 0, mode: WorkdayMode = .fullDay) throws -> WorkSession {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoul
        let start = try XCTUnwrap(
            DateComponents(calendar: calendar, timeZone: seoul, year: 2026, month: 6, day: 10, hour: hour, minute: minute).date
        )
        return WorkSession(workDate: "2026-06-10", workStartAt: start, workdayMode: mode)
    }

    func testFullDayOwesEightWorkingHours() {
        XCTAssertEqual(WorkdayMode.fullDay.workDuration, 8 * 60 * 60)
    }

    func testHalfDayModesOweFourWorkingHours() {
        XCTAssertEqual(WorkdayMode.morningHalfDay.workDuration, 4 * 60 * 60)
        XCTAssertEqual(WorkdayMode.afternoonHalfDay.workDuration, 4 * 60 * 60)
    }

    func testMorningStartStillSpansTheLunchHour() throws {
        // 8h of work plus the lunch it runs through: the long-standing 9h wall-clock day.
        let session = try session(startingAt: 9)

        XCTAssertEqual(session.workdayDuration, 9 * 60 * 60, accuracy: 0.1)
        XCTAssertEqual(session.targetAt, session.workStartAt.addingTimeInterval(9 * 60 * 60))
    }

    func testAfternoonStartDoesNotPayForALunchItMissed() throws {
        // Starting after lunch, 8h of work ends 8h later — not 9h, which used to overshoot.
        let session = try session(startingAt: 13)

        XCTAssertEqual(session.workdayDuration, 8 * 60 * 60, accuracy: 0.1)
        XCTAssertEqual(
            LunchBreak.standard.creditedDuration(from: session.workStartAt, to: session.targetAt),
            8 * 60 * 60,
            accuracy: 0.1
        )
    }

    func testTargetAlwaysCreditsExactlyTheOwedWork() throws {
        for hour in [7, 9, 11, 12, 13, 15] {
            for mode in WorkdayMode.allCases {
                let session = try session(startingAt: hour, mode: mode)
                XCTAssertEqual(
                    LunchBreak.standard.creditedDuration(from: session.workStartAt, to: session.targetAt),
                    mode.workDuration,
                    accuracy: 0.1,
                    "\(mode) starting \(hour):00"
                )
            }
        }
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
