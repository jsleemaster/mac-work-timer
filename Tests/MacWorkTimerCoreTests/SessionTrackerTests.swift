import XCTest
@testable import MacWorkTimerCore

final class SessionTrackerTests: XCTestCase {
    func testUpdateWeeklyAttendanceCachePersistsLastSuccessfulRecords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(store: store)
        try store.save(.empty)
        let cache = WeeklyAttendanceCache(
            weekStart: "2026-07-20",
            fetchedAt: Date(timeIntervalSince1970: 1_784_678_400),
            records: [WeeklyAttendanceRecord(
                workDate: "2026-07-20",
                kind: .creditedLeave,
                creditedDuration: 8 * 60 * 60,
                sourceText: "2026-07-20 연차"
            )]
        )

        let updated = try tracker.updateWeeklyAttendanceCache(cache)

        XCTAssertEqual(updated.weeklyAttendanceCache, cache)
        XCTAssertEqual(try store.load().weeklyAttendanceCache, cache)
    }

    private let kstClock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)

    private func kst(day: Int = 11, _ hour: Int, _ minute: Int, _ second: Int = 0) throws -> Date {
        try XCTUnwrap(DateComponents(calendar: kstClock.calendar, timeZone: kstClock.calendar.timeZone, year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second).date)
    }

    private func makeTracker(_ state: AppState) throws -> (SessionTracker, StateStore) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        try store.save(state)
        return (SessionTracker(clock: kstClock, store: store), store)
    }

    private func weekly(_ records: [WeeklyAttendanceRecord]) throws -> WeeklyAttendanceCache {
        WeeklyAttendanceCache(weekStart: "2026-11-09", fetchedAt: try kst(7, 9), records: records)
    }

    private func checkIn(day: Int = 11, _ date: Date) -> WeeklyAttendanceRecord {
        WeeklyAttendanceRecord(workDate: String(format: "2026-11-%02d", day), kind: .attendance, checkInAt: date, sourceText: "출근")
    }

    func testWeeklyCheckInReplacesLocalFallbackStartForToday() throws {
        let localStart = try kst(5, 21, 19)
        let gwCheckIn = try kst(6, 39)
        let loginNeeded = GWStatus.requiresWebLogin("GW 웹 로그인이 필요합니다.")
        let (tracker, store) = try makeTracker(AppState(
            todaySession: WorkSession(workDate: "2026-11-11", workStartAt: localStart, workdayMode: .afternoonHalfDay),
            gwStatus: loginNeeded,
            notificationSentForDate: "2026-11-11"
        ))

        let updated = try tracker.updateWeeklyAttendanceCache(try weekly([checkIn(gwCheckIn)]), now: try kst(7, 9))

        XCTAssertEqual(updated.todaySession, WorkSession(workDate: "2026-11-11", workStartAt: gwCheckIn, workdayMode: .afternoonHalfDay))
        XCTAssertEqual(updated.currentSession(on: try kst(7, 9), clock: kstClock)?.workStartAt, gwCheckIn)
        XCTAssertEqual(updated.gwStatus, loginNeeded)
        XCTAssertNil(updated.notificationSentForDate)
        XCTAssertEqual(try store.load(), updated)
    }

    func testWeeklyCheckInUsesEarliestRowOfTheDay() throws {
        let (tracker, _) = try makeTracker(AppState(todaySession: WorkSession(workDate: "2026-11-11", workStartAt: try kst(5, 21)), gwStatus: .notConfigured, notificationSentForDate: nil))

        let updated = try tracker.updateWeeklyAttendanceCache(try weekly([checkIn(try kst(18, 30)), checkIn(try kst(6, 39))]), now: try kst(19, 0))

        XCTAssertEqual(updated.todaySession?.workStartAt, try kst(6, 39))
    }

    func testWeeklyCheckInDoesNotOverrideTodaysAttendanceRecord() throws {
        let record = AttendanceRecord(workDate: "2026-11-11", checkInAt: try kst(6, 39, 12), sourceText: "출근 2026.11.11 06:39:12")
        let (tracker, _) = try makeTracker(AppState(todaySession: record.session, gwStatus: .attendance(record), notificationSentForDate: "2026-11-11"))

        let updated = try tracker.updateWeeklyAttendanceCache(try weekly([checkIn(try kst(6, 39))]), now: try kst(9, 0))

        XCTAssertEqual(updated.todaySession, record.session)
        XCTAssertEqual(updated.gwStatus, .attendance(record))
        XCTAssertEqual(updated.notificationSentForDate, "2026-11-11")
    }

    func testNewerWeeklyCheckInUpdatesAnEarlierWeeklyStart() throws {
        let (tracker, _) = try makeTracker(AppState(todaySession: WorkSession(workDate: "2026-11-11", workStartAt: try kst(5, 21)), gwStatus: .notConfigured, notificationSentForDate: nil))
        _ = try tracker.updateWeeklyAttendanceCache(try weekly([checkIn(try kst(6, 39))]), now: try kst(7, 0))

        let updated = try tracker.updateWeeklyAttendanceCache(try weekly([checkIn(try kst(7, 10))]), now: try kst(9, 0))

        XCTAssertEqual(updated.todaySession?.workStartAt, try kst(7, 10))
    }

    func testStartOrResumeKeepsWeeklyCheckInAfterTodayLookupFailsAgain() throws {
        let localStart = try kst(5, 21, 19)
        let (tracker, _) = try makeTracker(AppState(todaySession: WorkSession(workDate: "2026-11-11", workStartAt: localStart), gwStatus: .notConfigured, notificationSentForDate: nil))
        _ = try tracker.updateWeeklyAttendanceCache(try weekly([checkIn(try kst(6, 39))]), now: try kst(7, 0))
        _ = try tracker.updateGWStatus(.requiresWebLogin("GW 웹 로그인이 필요합니다."))
        _ = try tracker.markNotificationSent(for: "2026-11-11")

        let updated = try tracker.startOrResume(now: try kst(9, 0), preferredStart: localStart)

        XCTAssertEqual(updated.todaySession?.workStartAt, try kst(6, 39))
        XCTAssertEqual(updated.notificationSentForDate, "2026-11-11")
    }

    func testStartOrResumeSeedsNewSessionFromCachedWeeklyCheckIn() throws {
        var state = AppState.empty
        state.weeklyAttendanceCache = try weekly([checkIn(try kst(6, 39))])
        let (tracker, _) = try makeTracker(state)

        let updated = try tracker.startOrResume(now: try kst(9, 0), preferredStart: try kst(5, 21))

        XCTAssertEqual(updated.todaySession?.workStartAt, try kst(6, 39))
    }

    func testWeeklyCheckInLeavesPreviousDaySessionAlone() throws {
        let yesterday = WorkSession(workDate: "2026-11-10", workStartAt: try kst(day: 10, 9, 0))
        let (tracker, _) = try makeTracker(AppState(todaySession: yesterday, gwStatus: .notConfigured, notificationSentForDate: "2026-11-10"))

        let updated = try tracker.updateWeeklyAttendanceCache(try weekly([checkIn(day: 10, try kst(day: 10, 10, 22))]), now: try kst(0, 30))

        XCTAssertEqual(updated.todaySession, yesterday)
        XCTAssertEqual(updated.notificationSentForDate, "2026-11-10")
    }

    func testWeeklyRecordWithoutCheckInKeepsLocalSession() throws {
        let session = WorkSession(workDate: "2026-11-11", workStartAt: try kst(9, 0))
        let (tracker, _) = try makeTracker(AppState(todaySession: session, gwStatus: .notConfigured, notificationSentForDate: nil))
        let leave = WeeklyAttendanceRecord(workDate: "2026-11-11", kind: .creditedLeave, creditedDuration: 4 * 60 * 60, sourceText: "2026-11-11 반차")

        let updated = try tracker.updateWeeklyAttendanceCache(try weekly([leave]), now: try kst(9, 30))

        XCTAssertEqual(updated.todaySession, session)
        XCTAssertEqual(updated.gwStatus, .notConfigured)
    }

    func testClearingLoginStateClearsWeeklyAttendanceCache() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(store: store)
        let cache = WeeklyAttendanceCache(
            weekStart: "2026-07-20",
            fetchedAt: Date(timeIntervalSince1970: 1_784_678_400),
            records: []
        )
        try store.save(AppState(
            todaySession: nil,
            gwStatus: .notConfigured,
            notificationSentForDate: nil,
            weeklyAttendanceCache: cache
        ))

        let updated = try tracker.clearSessionAndGWStatus()

        XCTAssertNil(updated.weeklyAttendanceCache)
    }

    func testStartOrResumeCreatesTodaySessionWhenStoredSessionIsStale() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(clock: clock, store: store)
        let previousStart = try XCTUnwrap(DateComponents(
            calendar: clock.calendar,
            timeZone: clock.calendar.timeZone,
            year: 2026,
            month: 5,
            day: 27,
            hour: 9,
            minute: 10,
            second: 30
        ).date)
        let todayStart = try XCTUnwrap(DateComponents(
            calendar: clock.calendar,
            timeZone: clock.calendar.timeZone,
            year: 2026,
            month: 5,
            day: 29,
            hour: 13,
            minute: 40,
            second: 0
        ).date)
        try store.save(AppState(
            todaySession: WorkSession(workDate: "2026-05-27", workStartAt: previousStart),
            gwStatus: .requiresWebLogin("old"),
            notificationSentForDate: nil
        ))

        let updated = try tracker.startOrResume(now: todayStart)

        XCTAssertEqual(updated.todaySession, WorkSession(workDate: "2026-05-29", workStartAt: todayStart))
        XCTAssertEqual(try store.load().todaySession, updated.todaySession)
    }

    func testStartOrResumeUsesEarlierPreferredStartForToday() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(clock: clock, store: store)
        let appStart = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 5, day: 29, hour: 11, minute: 1, second: 41).date)
        let firstActivity = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 5, day: 29, hour: 8, minute: 55, second: 0).date)
        try store.save(AppState(
            todaySession: WorkSession(workDate: "2026-05-29", workStartAt: appStart),
            gwStatus: .requiresWebLogin("old"),
            notificationSentForDate: nil
        ))

        let updated = try tracker.startOrResume(now: appStart, preferredStart: firstActivity)

        XCTAssertEqual(updated.todaySession, WorkSession(workDate: "2026-05-29", workStartAt: firstActivity))
    }

    func testStartOrResumeRepairsEarlierLocalFallbackWithLaterPreferredStartForToday() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(clock: clock, store: store)
        let staleFallback = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 6, day: 16, hour: 0, minute: 16, second: 25).date)
        let firstFreshInput = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 6, day: 16, hour: 9, minute: 46, second: 40).date)
        let now = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 6, day: 16, hour: 13, minute: 36, second: 25).date)
        try store.save(AppState(
            todaySession: WorkSession(workDate: "2026-06-16", workStartAt: staleFallback),
            gwStatus: .requiresWebLogin("GW 웹 로그인이 필요합니다."),
            notificationSentForDate: "2026-06-16"
        ))

        let updated = try tracker.startOrResume(now: now, preferredStart: firstFreshInput)

        XCTAssertEqual(updated.todaySession, WorkSession(workDate: "2026-06-16", workStartAt: firstFreshInput))
        XCTAssertNil(updated.notificationSentForDate)
    }

    func testStartOrResumeDoesNotReplaceAttendanceRecordWithLocalPreferredStart() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(clock: clock, store: store)
        let attendanceStart = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 6, day: 16, hour: 9, minute: 15, second: 0).date)
        let localPreferredStart = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 6, day: 16, hour: 9, minute: 46, second: 40).date)
        let now = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 6, day: 16, hour: 13, minute: 36, second: 25).date)
        let record = AttendanceRecord(workDate: "2026-06-16", checkInAt: attendanceStart, sourceText: "출근 2026.06.16 09:15:00")
        try store.save(AppState(
            todaySession: record.session,
            gwStatus: .attendance(record),
            notificationSentForDate: nil
        ))

        let updated = try tracker.startOrResume(now: now, preferredStart: localPreferredStart)

        XCTAssertEqual(updated.todaySession, record.session)
        XCTAssertEqual(updated.currentSession(on: now, clock: clock), record.session)
    }

    func testCompletePetRevealPersistsSelectedPet() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(store: store)
        let state = AppState.empty
        try store.save(state)

        let updated = try tracker.completePetReveal(
            for: "2026-05-19",
            availablePetIDs: ["mint"],
            picker: { _ in "mint" }
        )
        let loaded = try store.load()

        XCTAssertEqual(updated.petReveal?.selectedPetID, "mint")
        XCTAssertEqual(loaded.petReveal?.selectedPetID, "mint")
        XCTAssertEqual(loaded.petReveal?.workDate, "2026-05-19")
    }

    func testSettingHolidayPersistsEntryAndClearsThatDaysSession() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(clock: clock, store: store)
        let start = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 6, day: 10, hour: 9).date)
        try store.save(AppState(
            todaySession: WorkSession(workDate: "2026-06-10", workStartAt: start),
            gwStatus: .notConfigured,
            notificationSentForDate: "2026-06-10"
        ))

        let updated = try tracker.setHoliday(true, for: "2026-06-10", title: "창립기념일")

        XCTAssertEqual(updated.holidays, [HolidayEntry(workDate: "2026-06-10", title: "창립기념일")])
        XCTAssertNil(updated.todaySession)
        XCTAssertNil(updated.notificationSentForDate)
        XCTAssertNil(try store.load().currentSession(on: start, clock: clock))
    }

    func testSettingHolidayOnAPastDateKeepsTodaysRunningSession() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(clock: clock, store: store)
        let start = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 8, day: 19, hour: 9).date)
        try store.save(AppState(
            todaySession: WorkSession(workDate: "2026-08-19", workStartAt: start),
            gwStatus: .notConfigured,
            notificationSentForDate: "2026-08-19"
        ))

        // A holiday is usually noticed after the fact, so registering Monday on Wednesday must
        // leave Wednesday's timer running.
        let updated = try tracker.setHoliday(true, for: "2026-08-17", title: "창립기념일")

        XCTAssertEqual(updated.holidays, [HolidayEntry(workDate: "2026-08-17", title: "창립기념일")])
        XCTAssertEqual(updated.todaySession?.workDate, "2026-08-19")
        XCTAssertEqual(updated.notificationSentForDate, "2026-08-19")
    }

    func testUnsettingHolidayRemovesOnlyThatEntry() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(store: store)
        var state = AppState.empty
        state.holidays = [
            HolidayEntry(workDate: "2026-06-10", title: "창립기념일"),
            HolidayEntry(workDate: "2026-06-11", title: "휴일")
        ]
        try store.save(state)

        let updated = try tracker.setHoliday(false, for: "2026-06-10", title: nil)

        XCTAssertEqual(updated.holidays, [HolidayEntry(workDate: "2026-06-11", title: "휴일")])
    }

    func testSettingTheSameHolidayTwiceKeepsOneEntryAndUpdatesTitle() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(store: store)
        try store.save(.empty)

        _ = try tracker.setHoliday(true, for: "2026-06-10", title: "휴일")
        let updated = try tracker.setHoliday(true, for: "2026-06-10", title: "창립기념일")

        XCTAssertEqual(updated.holidays, [HolidayEntry(workDate: "2026-06-10", title: "창립기념일")])
    }

    func testHolidaysStaySortedByDate() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(store: store)
        try store.save(.empty)

        _ = try tracker.setHoliday(true, for: "2026-09-01", title: "창립기념일")
        let updated = try tracker.setHoliday(true, for: "2026-08-17", title: "대체공휴일")

        XCTAssertEqual(updated.holidays.map(\.workDate), ["2026-08-17", "2026-09-01"])
    }

    func testBlankHolidayTitleFallsBackToDefault() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(store: store)
        try store.save(.empty)

        let updated = try tracker.setHoliday(true, for: "2026-08-17", title: "   ")

        XCTAssertEqual(updated.holidays.first?.title, HolidayEntry.defaultTitle)
    }

    func testStartOrResumeDoesNotCreateASessionOnAHoliday() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(clock: clock, store: store)
        var state = AppState.empty
        state.holidays = [HolidayEntry(workDate: "2026-06-10", title: "창립기념일")]
        try store.save(state)
        let now = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 6, day: 10, hour: 9).date)

        let updated = try tracker.startOrResume(now: now)

        XCTAssertNil(updated.todaySession)
    }

    func testSetWorkdayModePersistsSelectionForDate() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(clock: clock, store: store)
        let start = try XCTUnwrap(DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, year: 2026, month: 6, day: 10, hour: 13, minute: 30).date)
        try store.save(AppState(
            todaySession: WorkSession(workDate: "2026-06-10", workStartAt: start),
            gwStatus: .notConfigured,
            notificationSentForDate: nil
        ))

        let updated = try tracker.setWorkdayMode(.morningHalfDay, for: "2026-06-10")

        XCTAssertEqual(updated.workdayModeSelection, WorkdayModeSelection(workDate: "2026-06-10", mode: .morningHalfDay))
        XCTAssertEqual(try store.load().currentSession(on: start, clock: clock)?.workdayMode, .morningHalfDay)
    }
}
