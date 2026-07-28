import XCTest
@testable import MacWorkTimerCore

final class WeeklyWorkBalanceCalculatorTests: XCTestCase {
    private let calculator = WeeklyWorkBalanceCalculator()

    func testMondayWorkSubtractsLunchOverlap() throws {
        let record = try attendance("2026-07-20", "09:21", "18:44")

        XCTAssertEqual(
            calculator.creditedDuration(for: [record]),
            8 * 60 * 60 + 23 * 60,
            accuracy: 0.1
        )
    }

    func testMondayAndTuesdayLeaveNineMinutesForWednesday() throws {
        let records = try [
            attendance("2026-07-20", "09:21", "18:44"),
            attendance("2026-07-21", "09:50", "18:36")
        ]
        let session = WorkSession(
            workDate: "2026-07-22",
            workStartAt: try date("2026-07-22", "09:35")
        )

        let summary = try XCTUnwrap(calculator.summary(
            records: records,
            todaySession: session,
            fetchedAt: try date("2026-07-22", "10:00")
        ))

        XCTAssertTrue(summary.isComplete)
        XCTAssertEqual(summary.balance, 9 * 60, accuracy: 0.1)
        XCTAssertEqual(summary.normalTargetAt, try date("2026-07-22", "18:35"))
        XCTAssertEqual(summary.allFlexUsedTargetAt, try date("2026-07-22", "18:26"))
    }

    func testNineMinuteShortageExtendsTodayTargetByNineMinutes() throws {
        let records = try [
            attendance("2026-07-20", "09:21", "18:12"),
            attendance("2026-07-21", "09:21", "18:21")
        ]
        let session = WorkSession(
            workDate: "2026-07-22",
            workStartAt: try date("2026-07-22", "09:07")
        )

        let summary = try XCTUnwrap(calculator.summary(
            records: records,
            todaySession: session,
            fetchedAt: try date("2026-07-22", "10:00")
        ))

        XCTAssertTrue(summary.isComplete)
        XCTAssertEqual(summary.balance, -9 * 60, accuracy: 0.1)
        XCTAssertEqual(summary.normalTargetAt, try date("2026-07-22", "18:07"))
        XCTAssertEqual(summary.allFlexUsedTargetAt, try date("2026-07-22", "18:16"))
    }

    func testLunchDeductionUsesOnlyActualOverlap() throws {
        let partialLunch = try attendance("2026-07-20", "12:30", "18:00")
        let noLunch = try attendance("2026-07-21", "13:00", "18:00")

        XCTAssertEqual(calculator.creditedDuration(for: [partialLunch]), 5 * 60 * 60, accuracy: 0.1)
        XCTAssertEqual(calculator.creditedDuration(for: [noLunch]), 5 * 60 * 60, accuracy: 0.1)
    }

    func testAttendanceAndHalfDayLeaveCreditsBothCount() throws {
        let worked = try attendance("2026-07-20", "09:21", "14:23")
        let leave = WeeklyAttendanceRecord(
            workDate: "2026-07-20",
            kind: .creditedLeave,
            creditedDuration: 4 * 60 * 60,
            sourceText: "2026-07-20 법정휴가 오후반차"
        )

        XCTAssertEqual(
            calculator.creditedDuration(for: [worked, leave]),
            8 * 60 * 60 + 2 * 60,
            accuracy: 0.1
        )
    }

    func testMissingPreviousWeekdayMakesSummaryIncomplete() throws {
        let session = WorkSession(
            workDate: "2026-07-22",
            workStartAt: try date("2026-07-22", "09:35")
        )
        let records = try [attendance("2026-07-20", "09:21", "18:44")]

        let summary = try XCTUnwrap(calculator.summary(
            records: records,
            todaySession: session,
            fetchedAt: try date("2026-07-22", "10:00")
        ))

        XCTAssertFalse(summary.isComplete)
        XCTAssertEqual(summary.incompleteWorkDates, ["2026-07-21"])
        XCTAssertEqual(summary.allFlexUsedTargetAt, summary.normalTargetAt)
    }

    func testExplicitAbsenceCountsAsACompleteZeroHourDay() throws {
        let absence = WeeklyAttendanceRecord(
            workDate: "2026-07-20",
            kind: .explicitAbsence,
            sourceText: "2026-07-20 결근"
        )
        let session = WorkSession(
            workDate: "2026-07-21",
            workStartAt: try date("2026-07-21", "09:00")
        )

        let summary = try XCTUnwrap(calculator.summary(
            records: [absence],
            todaySession: session,
            fetchedAt: try date("2026-07-21", "10:00")
        ))

        XCTAssertTrue(summary.isComplete)
        XCTAssertEqual(summary.balance, -8 * 60 * 60, accuracy: 0.1)
        XCTAssertEqual(summary.allFlexUsedTargetAt, try date("2026-07-22", "02:00"))
    }

    func testMondayStartsWithZeroBalance() throws {
        let session = WorkSession(
            workDate: "2026-07-20",
            workStartAt: try date("2026-07-20", "09:00")
        )

        let summary = try XCTUnwrap(calculator.summary(
            records: [],
            todaySession: session,
            fetchedAt: try date("2026-07-20", "09:30")
        ))

        XCTAssertTrue(summary.isComplete)
        XCTAssertEqual(summary.weekStart, "2026-07-20")
        XCTAssertEqual(summary.balance, 0, accuracy: 0.1)
    }

    func testUsingLargePositiveBalanceNeverTargetsBeforeCheckIn() throws {
        let records = [
            WeeklyAttendanceRecord(
                workDate: "2026-07-20",
                kind: .creditedLeave,
                creditedDuration: 20 * 60 * 60,
                sourceText: "fixture"
            )
        ]
        let checkIn = try date("2026-07-21", "09:00")
        let session = WorkSession(workDate: "2026-07-21", workStartAt: checkIn)

        let summary = try XCTUnwrap(calculator.summary(
            records: records,
            todaySession: session,
            fetchedAt: try date("2026-07-21", "09:30")
        ))

        XCTAssertEqual(summary.allFlexUsedTargetAt, checkIn)
    }

    func testCacheFromDifferentMondayIsIgnored() throws {
        let session = WorkSession(
            workDate: "2026-07-22",
            workStartAt: try date("2026-07-22", "09:35")
        )
        let staleCache = WeeklyAttendanceCache(
            weekStart: "2026-07-13",
            fetchedAt: try date("2026-07-17", "18:00"),
            records: try [attendance("2026-07-17", "09:00", "18:00")]
        )

        XCTAssertNil(calculator.summary(cache: staleCache, todaySession: session))
    }

    func testCurrentWeekCacheBuildsSummary() throws {
        let session = WorkSession(
            workDate: "2026-07-21",
            workStartAt: try date("2026-07-21", "09:35")
        )
        let cache = WeeklyAttendanceCache(
            weekStart: "2026-07-20",
            fetchedAt: try date("2026-07-21", "10:00"),
            records: try [attendance("2026-07-20", "09:21", "18:44")]
        )

        let summary = try XCTUnwrap(calculator.summary(cache: cache, todaySession: session))

        XCTAssertEqual(summary.balance, 23 * 60, accuracy: 0.1)
    }

    private func attendance(_ workDate: String, _ checkIn: String, _ checkOut: String) throws -> WeeklyAttendanceRecord {
        WeeklyAttendanceRecord(
            workDate: workDate,
            kind: .attendance,
            checkInAt: try date(workDate, checkIn),
            checkOutAt: try date(workDate, checkOut),
            sourceText: "\(workDate) \(checkIn) \(checkOut)"
        )
    }

    private func date(_ workDate: String, _ time: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return try XCTUnwrap(formatter.date(from: "\(workDate) \(time)"))
    }
}
