import XCTest
@testable import MacWorkTimerCore

final class PetEvolutionStageTests: XCTestCase {
    func testNineHourWorkdayIsSplitIntoThreeEvolutionStages() {
        let duration: TimeInterval = 9 * 60 * 60

        XCTAssertEqual(PetEvolutionStage.stage(elapsed: 0, duration: duration), .base)
        XCTAssertEqual(PetEvolutionStage.stage(elapsed: 3 * 60 * 60 - 1, duration: duration), .base)
        XCTAssertEqual(PetEvolutionStage.stage(elapsed: 3 * 60 * 60, duration: duration), .middle)
        XCTAssertEqual(PetEvolutionStage.stage(elapsed: 6 * 60 * 60 - 1, duration: duration), .middle)
        XCTAssertEqual(PetEvolutionStage.stage(elapsed: 6 * 60 * 60, duration: duration), .final)
        XCTAssertEqual(PetEvolutionStage.stage(elapsed: duration, duration: duration), .final)
    }

    func testNilElapsedUsesBaseStage() {
        XCTAssertEqual(PetEvolutionStage.stage(elapsed: nil, duration: 9 * 60 * 60), .base)
    }

    func testStageIndexUsesAvailableStageCount() {
        let duration: TimeInterval = 9 * 60 * 60

        XCTAssertEqual(PetEvolutionStage.stageIndex(elapsed: 0, duration: duration, stageCount: 4), 0)
        XCTAssertEqual(PetEvolutionStage.stageIndex(elapsed: duration / 4 - 1, duration: duration, stageCount: 4), 0)
        XCTAssertEqual(PetEvolutionStage.stageIndex(elapsed: duration / 4, duration: duration, stageCount: 4), 1)
        XCTAssertEqual(PetEvolutionStage.stageIndex(elapsed: duration / 2, duration: duration, stageCount: 4), 2)
        XCTAssertEqual(PetEvolutionStage.stageIndex(elapsed: duration, duration: duration, stageCount: 4), 3)
    }

    func testInvalidStageCountFallsBackToFirstStageIndex() {
        XCTAssertEqual(PetEvolutionStage.stageIndex(elapsed: 60, duration: 9 * 60 * 60, stageCount: 0), 0)
    }
}
