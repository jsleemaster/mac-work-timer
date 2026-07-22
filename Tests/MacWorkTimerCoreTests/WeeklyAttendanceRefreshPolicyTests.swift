import XCTest
@testable import MacWorkTimerCore

final class WeeklyAttendanceRefreshPolicyTests: XCTestCase {
    func testAuthenticatedSessionRestartsRefreshAlreadyInProgress() {
        XCTAssertTrue(
            WeeklyAttendanceRefreshPolicy.shouldStart(
                isRefreshInProgress: true,
                reason: .authenticatedWebSession
            )
        )
    }

    func testRoutineRefreshDoesNotDuplicateRefreshAlreadyInProgress() {
        XCTAssertFalse(
            WeeklyAttendanceRefreshPolicy.shouldStart(
                isRefreshInProgress: true,
                reason: .routine
            )
        )
    }
}
