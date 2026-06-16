import XCTest
@testable import MacWorkTimerCore

final class MainWindowPresentationPolicyTests: XCTestCase {
    func testLaunchShowsPetOnly() {
        XCTAssertFalse(MainWindowPresentationPolicy.shouldShowMainWindowOnLaunch)
    }

    func testLoginWindowOpensOnlyWhenSessionIsMissing() {
        XCTAssertTrue(MainWindowPresentationPolicy.shouldOpenLoginWindow(hasSession: false))
        XCTAssertFalse(MainWindowPresentationPolicy.shouldOpenLoginWindow(hasSession: true))
    }

    func testMainWindowHidesAfterSessionStarts() {
        XCTAssertTrue(MainWindowPresentationPolicy.shouldHideMainWindow(hasSession: true))
        XCTAssertFalse(MainWindowPresentationPolicy.shouldHideMainWindow(hasSession: false))
    }
}
