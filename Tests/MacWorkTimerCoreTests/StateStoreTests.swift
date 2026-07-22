import XCTest
@testable import MacWorkTimerCore

final class StateStoreTests: XCTestCase {
    func testWeeklyAttendanceCacheRoundTripPersistsRecords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let fetchedAt = Date(timeIntervalSince1970: 1_784_678_400)
        let cache = WeeklyAttendanceCache(
            weekStart: "2026-07-20",
            fetchedAt: fetchedAt,
            records: [WeeklyAttendanceRecord(
                workDate: "2026-07-20",
                kind: .explicitAbsence,
                sourceText: "2026-07-20 결근"
            )]
        )
        let state = AppState(
            todaySession: nil,
            gwStatus: .notConfigured,
            notificationSentForDate: nil,
            weeklyAttendanceCache: cache
        )

        try store.save(state)

        XCTAssertEqual(try store.load().weeklyAttendanceCache, cache)
    }

    func testOldStateWithoutWeeklyCacheStillDecodes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = """
        {
          "gwStatus" : { "notConfigured" : {} },
          "notificationSentForDate" : "2026-07-20",
          "petReveal" : null,
          "todaySession" : null,
          "workdayModeSelection" : null
        }
        """
        try Data(json.utf8).write(to: directory.appendingPathComponent("state.json"))
        let loaded = try StateStore(directory: directory).load()

        XCTAssertEqual(loaded.notificationSentForDate, "2026-07-20")
        XCTAssertNil(loaded.weeklyAttendanceCache)
    }

    func testStateRoundTripPersistsSessionAndGWStatus() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let session = WorkSession(workDate: "2026-05-19", workStartAt: Date(timeIntervalSince1970: 1_779_158_400))
        let state = AppState(todaySession: session, gwStatus: .notConfigured, notificationSentForDate: nil)

        try store.save(state)
        let loaded = try store.load()

        XCTAssertEqual(loaded.todaySession, session)
        XCTAssertEqual(loaded.gwStatus, .notConfigured)
        XCTAssertNil(loaded.notificationSentForDate)
    }

    func testMissingStateLoadsDefaultState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)

        XCTAssertEqual(try store.load(), .empty)
    }

    func testCorruptStateLoadsDefaultState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: directory.appendingPathComponent("state.json"))
        let store = StateStore(directory: directory)

        XCTAssertEqual(try store.load(), .empty)
    }

    func testCurrentSessionFallsBackToStoredSessionWhenGWRefreshFails() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let start = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 5, day: 19, hour: 9, minute: 25, second: 7).date)
        let now = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 5, day: 19, hour: 14, minute: 46).date)
        let session = WorkSession(workDate: clock.workDate(for: start), workStartAt: start)
        let state = AppState(todaySession: session, gwStatus: .failed("Could not connect to the server."), notificationSentForDate: nil)

        XCTAssertEqual(state.currentSession(on: now, clock: clock), session)
    }

    func testCurrentSessionIgnoresStoredSessionFromDifferentDay() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let start = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 5, day: 18, hour: 9).date)
        let now = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 5, day: 19, hour: 9).date)
        let session = WorkSession(workDate: clock.workDate(for: start), workStartAt: start)
        let state = AppState(todaySession: session, gwStatus: .failed("offline"), notificationSentForDate: nil)

        XCTAssertNil(state.currentSession(on: now, clock: clock))
    }
}
