import XCTest
@testable import MacWorkTimerCore

final class PetMoodTests: XCTestCase {
    func testMissingRemainingTimeUsesIdleMood() {
        XCTAssertEqual(PetMood.mood(remaining: nil), .idle)
    }

    func testRemainingTimeUsesWorkingMoodAboveOneHour() {
        XCTAssertEqual(PetMood.mood(remaining: 60 * 60 + 1), .working)
    }

    func testRemainingTimeUsesUnderOneHourMood() {
        XCTAssertEqual(PetMood.mood(remaining: 60 * 60 - 1), .under1h)
    }

    func testRemainingTimeUsesUnderThirtyMinutesMood() {
        XCTAssertEqual(PetMood.mood(remaining: 30 * 60 - 1), .under30m)
    }

    func testRemainingTimeUsesUnderFiveMinutesMood() {
        XCTAssertEqual(PetMood.mood(remaining: 5 * 60 - 1), .under5m)
    }

    func testZeroRemainingTimeUsesDoneMood() {
        XCTAssertEqual(PetMood.mood(remaining: 0), .done)
    }
}
