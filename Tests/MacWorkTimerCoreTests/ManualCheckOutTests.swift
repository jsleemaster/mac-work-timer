import XCTest
@testable import MacWorkTimerCore

/// A forgotten tag-out leaves GW with a check-in and no check-out. That one gap kept the weekly
/// summary incomplete, and with it the login window open, for the rest of the week.
final class ManualCheckOutTests: XCTestCase {
    private let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
    private let calculator = WeeklyWorkBalanceCalculator()

    private func kst(_ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        try XCTUnwrap(DateComponents(
            calendar: clock.calendar,
            timeZone: clock.calendar.timeZone,
            year: 2026, month: 11, day: day, hour: hour, minute: minute
        ).date)
    }

    private func attendance(_ day: Int, _ checkIn: (Int, Int), _ checkOut: (Int, Int)?) throws -> WeeklyAttendanceRecord {
        WeeklyAttendanceRecord(
            workDate: String(format: "2026-11-%02d", day),
            kind: .attendance,
            checkInAt: try kst(day, checkIn.0, checkIn.1),
            checkOutAt: try checkOut.map { try kst(day, $0.0, $0.1) },
            sourceText: "fixture"
        )
    }

    /// The week that reported the bug: Wednesday clocked in at 06:39 and never out.
    private func reportedWeek() throws -> AppState {
        let records = try [
            attendance(12, (10, 8), nil),
            WeeklyAttendanceRecord(workDate: "2026-11-11", kind: .creditedLeave, creditedDuration: 2 * 60 * 60, sourceText: "반반차"),
            attendance(11, (6, 39), nil),
            attendance(10, (10, 22), (19, 24)),
            attendance(9, (10, 19), (19, 48))
        ]
        return AppState(
            todaySession: WorkSession(workDate: "2026-11-12", workStartAt: try kst(12, 10, 8)),
            gwStatus: .notConfigured,
            notificationSentForDate: nil,
            weeklyAttendanceCache: WeeklyAttendanceCache(weekStart: "2026-11-09", fetchedAt: try kst(12, 11, 12), records: records)
        )
    }

    private func makeTracker(_ state: AppState) throws -> (SessionTracker, StateStore) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        try store.save(state)
        return (SessionTracker(clock: clock, store: store), store)
    }

    private func summary(_ state: AppState) throws -> WeeklyWorkSummary {
        try XCTUnwrap(calculator.summary(
            cache: try XCTUnwrap(state.effectiveWeeklyAttendanceCache),
            todaySession: try XCTUnwrap(state.todaySession)
        ))
    }

    func testMissingCheckOutListsOnlyPastOpenDays() throws {
        let state = try reportedWeek()

        // Today's open check-in is the running day, not a gap.
        XCTAssertEqual(state.missingCheckOuts(before: "2026-11-12").map(\.workDate), ["2026-11-11"])
        XCTAssertFalse(try summary(state).isComplete)
    }

    func testManualCheckOutCompletesTheWeek() throws {
        let (tracker, store) = try makeTracker(try reportedWeek())

        let updated = try tracker.setManualCheckOut(try kst(11, 15, 39), for: "2026-11-11")

        XCTAssertEqual(try store.load().manualCheckOuts, [ManualCheckOut(workDate: "2026-11-11", checkOutAt: try kst(11, 15, 39))])
        XCTAssertTrue(updated.missingCheckOuts(before: "2026-11-12").isEmpty)
        let summary = try summary(updated)
        XCTAssertTrue(summary.isComplete)
        // Mon 8h29 + Tue 8h02 + Wed (06:39-15:39 less lunch = 8h) + 반반차 2h, against 24h.
        XCTAssertEqual(summary.balance, (2 * 60 + 31) * 60, accuracy: 0.1)
    }

    func testGroupwareCheckOutWinsOverManualEntry() throws {
        var state = try reportedWeek()
        state.manualCheckOuts = [ManualCheckOut(workDate: "2026-11-11", checkOutAt: try kst(11, 15, 39))]
        let corrected = try state.weeklyAttendanceCache!.records.map { record in
            record.workDate == "2026-11-11" && record.kind == .attendance
                ? try attendance(11, (6, 39), (18, 0))
                : record
        }
        state.weeklyAttendanceCache = WeeklyAttendanceCache(weekStart: "2026-11-09", fetchedAt: try kst(12, 12, 0), records: corrected)

        let wednesday = state.effectiveWeeklyAttendanceCache?.records.first { $0.workDate == "2026-11-11" && $0.kind == .attendance }
        XCTAssertEqual(wednesday?.checkOutAt, try kst(11, 18, 0))
    }

    func testCheckOutBeforeCheckInIsIgnored() throws {
        var state = try reportedWeek()
        state.manualCheckOuts = [ManualCheckOut(workDate: "2026-11-11", checkOutAt: try kst(11, 6, 0))]

        XCTAssertEqual(state.missingCheckOuts(before: "2026-11-12").map(\.workDate), ["2026-11-11"])
    }

    func testClearingAndOldWeeksAreDropped() throws {
        var state = try reportedWeek()
        state.manualCheckOuts = [ManualCheckOut(workDate: "2026-11-04", checkOutAt: try kst(4, 18, 0))]
        let (tracker, store) = try makeTracker(state)

        try tracker.setManualCheckOut(try kst(11, 15, 39), for: "2026-11-11")
        XCTAssertEqual(try store.load().manualCheckOuts.map(\.workDate), ["2026-11-11"])

        try tracker.setManualCheckOut(nil, for: "2026-11-11")
        XCTAssertTrue(try store.load().manualCheckOuts.isEmpty)
    }

    func testLogoutKeepsManualCheckOuts() throws {
        var state = try reportedWeek()
        state.manualCheckOuts = [ManualCheckOut(workDate: "2026-11-11", checkOutAt: try kst(11, 15, 39))]
        let (tracker, store) = try makeTracker(state)

        try tracker.clearSessionAndGWStatus()

        XCTAssertEqual(try store.load().manualCheckOuts.count, 1)
    }

    func testStateSavedBeforeTheFeatureStillDecodes() throws {
        let json = #"{"gwStatus":{"notConfigured":{}}}"#.data(using: .utf8)!

        let state = try JSONDecoder().decode(AppState.self, from: json)

        XCTAssertTrue(state.manualCheckOuts.isEmpty)
    }
}
