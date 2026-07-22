import XCTest
@testable import MacWorkTimerCore

final class RefreshGenerationTrackerTests: XCTestCase {
    func testBeginningReplacementInvalidatesPreviousGeneration() {
        var tracker = RefreshGenerationTracker()
        let first = tracker.begin()
        let second = tracker.begin()

        XCTAssertFalse(tracker.isCurrent(first))
        XCTAssertTrue(tracker.isCurrent(second))
    }

    func testExplicitInvalidationRejectsCurrentGeneration() {
        var tracker = RefreshGenerationTracker()
        let generation = tracker.begin()

        tracker.invalidate()

        XCTAssertFalse(tracker.isCurrent(generation))
    }
}
