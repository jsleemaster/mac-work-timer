import XCTest
@testable import MacWorkTimerCore

final class PetClickActionTests: XCTestCase {
    func testIdleDisplayOpensLogin() {
        XCTAssertEqual(PetClickAction.action(for: .idle), .openLogin)
    }

    func testCapsuleDisplayRevealsCapsule() {
        XCTAssertEqual(PetClickAction.action(for: .capsuleIdle), .revealCapsule)
    }

    func testVisiblePetShowsStatusMessage() {
        XCTAssertEqual(PetClickAction.action(for: .petVisible("specter")), .showStatusMessage)
    }

    func testVisiblePetOpensLoginWhenWeeklySummaryNeedsRecovery() {
        XCTAssertEqual(
            PetClickAction.action(
                for: .petVisible("specter"),
                needsWeeklyLoginRecovery: true
            ),
            .openLogin
        )
    }
}
