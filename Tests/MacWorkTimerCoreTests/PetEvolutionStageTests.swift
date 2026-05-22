import XCTest
@testable import MacWorkTimerCore

final class PetEvolutionStageTests: XCTestCase {
    func testIdleAndWorkingUseBaseStage() {
        XCTAssertEqual(PetEvolutionStage.stage(mood: .idle), .base)
        XCTAssertEqual(PetEvolutionStage.stage(mood: .working), .base)
    }

    func testClosingTimeUsesMiddleStage() {
        XCTAssertEqual(PetEvolutionStage.stage(mood: .under1h), .middle)
        XCTAssertEqual(PetEvolutionStage.stage(mood: .under30m), .middle)
    }

    func testFinalMinutesAndDoneUseFinalStage() {
        XCTAssertEqual(PetEvolutionStage.stage(mood: .under5m), .final)
        XCTAssertEqual(PetEvolutionStage.stage(mood: .done), .final)
    }
}
