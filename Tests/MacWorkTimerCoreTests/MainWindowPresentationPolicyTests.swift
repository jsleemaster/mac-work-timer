import XCTest
@testable import MacWorkTimerCore

final class MainWindowPresentationPolicyTests: XCTestCase {
    func testLaunchShowsPetOnly() {
        XCTAssertFalse(MainWindowPresentationPolicy.shouldShowMainWindowOnLaunch)
    }

    func testLoginWindowOpensWhenSessionIsMissingOrWeeklyLoginNeedsRecovery() {
        XCTAssertTrue(
            MainWindowPresentationPolicy.shouldOpenLoginWindow(
                hasSession: false,
                needsWeeklyLoginRecovery: false
            )
        )
        XCTAssertTrue(
            MainWindowPresentationPolicy.shouldOpenLoginWindow(
                hasSession: true,
                needsWeeklyLoginRecovery: true
            )
        )
        XCTAssertFalse(
            MainWindowPresentationPolicy.shouldOpenLoginWindow(
                hasSession: true,
                needsWeeklyLoginRecovery: false
            )
        )
    }

    func testMainWindowStaysVisibleWhileWeeklyLoginNeedsRecovery() {
        XCTAssertTrue(
            MainWindowPresentationPolicy.shouldHideMainWindow(
                hasSession: true,
                needsWeeklyLoginRecovery: false
            )
        )
        XCTAssertFalse(
            MainWindowPresentationPolicy.shouldHideMainWindow(
                hasSession: true,
                needsWeeklyLoginRecovery: true
            )
        )
        XCTAssertFalse(
            MainWindowPresentationPolicy.shouldHideMainWindow(
                hasSession: false,
                needsWeeklyLoginRecovery: false
            )
        )
    }

    func testWeeklyLoginRecoveryNeedsSessionWithoutCompleteSummary() {
        XCTAssertTrue(
            MainWindowPresentationPolicy.needsWeeklyLoginRecovery(
                hasSession: true,
                hasCompleteWeeklySummary: false
            )
        )
        XCTAssertFalse(
            MainWindowPresentationPolicy.needsWeeklyLoginRecovery(
                hasSession: true,
                hasCompleteWeeklySummary: true
            )
        )
        XCTAssertFalse(
            MainWindowPresentationPolicy.needsWeeklyLoginRecovery(
                hasSession: false,
                hasCompleteWeeklySummary: false
            )
        )
    }
}
