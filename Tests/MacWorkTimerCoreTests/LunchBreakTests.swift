import XCTest
@testable import MacWorkTimerCore

final class LunchBreakTests: XCTestCase {
    private let lunch = LunchBreak.standard
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 8,
            day: 19,
            hour: hour,
            minute: minute
        ).date!
    }

    func testWindowIsOneHourAtNoon() {
        XCTAssertEqual(lunch.duration, 60 * 60, accuracy: 0.1)
    }

    // MARK: - overlap

    func testOverlapCountsOnlyTheLunchWindow() {
        XCTAssertEqual(lunch.overlap(with: DateInterval(start: at(9), end: at(18))), 60 * 60, accuracy: 0.1)
    }

    func testNoOverlapBeforeLunch() {
        XCTAssertEqual(lunch.overlap(with: DateInterval(start: at(9), end: at(12))), 0, accuracy: 0.1)
    }

    func testNoOverlapAfterLunch() {
        XCTAssertEqual(lunch.overlap(with: DateInterval(start: at(13), end: at(18))), 0, accuracy: 0.1)
    }

    func testPartialOverlapIsProrated() {
        XCTAssertEqual(
            lunch.overlap(with: DateInterval(start: at(11, 30), end: at(13, 30))),
            60 * 60,
            accuracy: 0.1
        )
        XCTAssertEqual(
            lunch.overlap(with: DateInterval(start: at(12, 30), end: at(14))),
            30 * 60,
            accuracy: 0.1
        )
    }

    // MARK: - creditedDuration

    func testCreditedDurationDropsTheLunchHour() {
        XCTAssertEqual(lunch.creditedDuration(from: at(9), to: at(18)), 8 * 60 * 60, accuracy: 0.1)
    }

    func testCreditedDurationKeepsEverythingWhenLunchIsNotSpanned() {
        XCTAssertEqual(lunch.creditedDuration(from: at(13), to: at(18)), 5 * 60 * 60, accuracy: 0.1)
        XCTAssertEqual(lunch.creditedDuration(from: at(10), to: at(12)), 2 * 60 * 60, accuracy: 0.1)
    }

    func testCreditedDurationIsNeverNegative() {
        XCTAssertEqual(lunch.creditedDuration(from: at(18), to: at(9)), 0, accuracy: 0.1)
        XCTAssertEqual(lunch.creditedDuration(from: at(12), to: at(13)), 0, accuracy: 0.1)
    }

    // MARK: - endOfWork

    func testEndOfWorkAddsTheLunchHourWhenTheDaySpansIt() {
        // The long-standing case: 09:00 + 8h of work lands at 18:00, not 17:00.
        XCTAssertEqual(lunch.endOfWork(startingAt: at(9), creditedWork: 8 * 60 * 60), at(18))
    }

    func testEndOfWorkDoesNotAddLunchForAShiftThatFinishesBeforeNoon() {
        // The flex-surplus case: only 1h of work left, so lunch is never reached.
        XCTAssertEqual(lunch.endOfWork(startingAt: at(9), creditedWork: 60 * 60), at(10))
        XCTAssertEqual(lunch.endOfWork(startingAt: at(9), creditedWork: 3 * 60 * 60), at(12))
    }

    func testEndOfWorkStepsOverLunchOnceTheWorkReachesIt() {
        XCTAssertEqual(lunch.endOfWork(startingAt: at(9), creditedWork: 3 * 60 * 60 + 30 * 60), at(13, 30))
        XCTAssertEqual(lunch.endOfWork(startingAt: at(11), creditedWork: 8 * 60 * 60), at(20))
    }

    func testEndOfWorkDoesNotAddLunchForAnAfternoonStart() {
        // The afternoon-start case: lunch is already over, so 8h of work ends 8h later.
        XCTAssertEqual(lunch.endOfWork(startingAt: at(13), creditedWork: 8 * 60 * 60), at(21))
        XCTAssertEqual(lunch.endOfWork(startingAt: at(14), creditedWork: 8 * 60 * 60), at(22))
    }

    func testEndOfWorkFromInsideLunchResumesAfterIt() {
        XCTAssertEqual(lunch.endOfWork(startingAt: at(12, 30), creditedWork: 4 * 60 * 60), at(17))
    }

    func testEndOfWorkWithNoWorkLeftIsTheStart() {
        XCTAssertEqual(lunch.endOfWork(startingAt: at(9), creditedWork: 0), at(9))
        XCTAssertEqual(lunch.endOfWork(startingAt: at(9), creditedWork: -3600), at(9))
    }

    /// `endOfWork` must be the exact inverse of `creditedDuration`; this is the property the two
    /// bugs violated, where a target time implied a different amount of work than it credited.
    func testEndOfWorkIsTheInverseOfCreditedDuration() {
        for startHour in [8, 9, 11, 12, 13, 14, 16] {
            for workMinutes in [0, 30, 60, 150, 180, 210, 300, 480, 600] {
                let start = at(startHour)
                let work = TimeInterval(workMinutes * 60)
                let end = lunch.endOfWork(startingAt: start, creditedWork: work)
                XCTAssertEqual(
                    lunch.creditedDuration(from: start, to: end),
                    work,
                    accuracy: 0.1,
                    "start \(startHour):00, work \(workMinutes)m -> \(end)"
                )
            }
        }
    }
}
