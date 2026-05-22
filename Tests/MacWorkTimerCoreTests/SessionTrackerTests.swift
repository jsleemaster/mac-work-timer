import XCTest
@testable import MacWorkTimerCore

final class SessionTrackerTests: XCTestCase {
    func testCompletePetRevealPersistsSelectedPet() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = StateStore(directory: directory)
        let tracker = SessionTracker(store: store)
        let state = AppState.empty
        try store.save(state)

        let updated = try tracker.completePetReveal(for: "2026-05-19", availablePetIDs: ["mint"], picker: { $0.first })
        let loaded = try store.load()

        XCTAssertEqual(updated.petReveal?.selectedPetID, "mint")
        XCTAssertEqual(loaded.petReveal?.selectedPetID, "mint")
        XCTAssertEqual(loaded.petReveal?.workDate, "2026-05-19")
    }
}
