import XCTest
@testable import MacWorkTimerCore

final class PetRevealStateTests: XCTestCase {
    func testMissingSessionUsesIdleRevealDisplay() throws {
        let state = AppState.empty

        XCTAssertEqual(state.petRevealDisplay(on: Date(), availablePetIDs: ["mint"]), .idle)
    }

    func testTodaySessionStartsWithCapsuleIdleBeforeReveal() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let start = try date(clock: clock, year: 2026, month: 5, day: 19, hour: 9, minute: 25)
        let session = WorkSession(workDate: clock.workDate(for: start), workStartAt: start)
        let state = AppState(todaySession: session, gwStatus: .notConfigured, notificationSentForDate: nil)

        XCTAssertEqual(state.petRevealDisplay(on: start, clock: clock, availablePetIDs: ["mint"]), .capsuleIdle)
    }

    func testRevealCompletionPersistsSelectedPetForSameDay() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let start = try date(clock: clock, year: 2026, month: 5, day: 19, hour: 9, minute: 25)
        let session = WorkSession(workDate: clock.workDate(for: start), workStartAt: start)
        var state = AppState(todaySession: session, gwStatus: .notConfigured, notificationSentForDate: nil)

        state.completePetReveal(for: session.workDate, availablePetIDs: ["mint"], picker: { _ in "mint" })

        XCTAssertEqual(state.petRevealDisplay(on: start, clock: clock, availablePetIDs: ["mint"]), .petVisible("mint"))
        XCTAssertEqual(state.petReveal?.workDate, "2026-05-19")
        XCTAssertTrue(state.petReveal?.isRevealed == true)
    }

    func testNextWorkdayResetsToCapsuleIdle() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let previousStart = try date(clock: clock, year: 2026, month: 5, day: 19, hour: 9, minute: 25)
        let nextStart = try date(clock: clock, year: 2026, month: 5, day: 20, hour: 9, minute: 20)
        let nextSession = WorkSession(workDate: clock.workDate(for: nextStart), workStartAt: nextStart)
        var state = AppState(todaySession: nextSession, gwStatus: .notConfigured, notificationSentForDate: nil)
        state.completePetReveal(for: clock.workDate(for: previousStart), availablePetIDs: ["mint"], picker: { $0.first })

        XCTAssertEqual(state.petRevealDisplay(on: nextStart, clock: clock, availablePetIDs: ["mint"]), .capsuleIdle)
    }

    func testRegisteredPetCanBeSelectedAlongsideDefaultPet() throws {
        var state = AppState.empty

        state.completePetReveal(for: "2026-05-19", availablePetIDs: ["mint"], picker: { _ in "mint" })

        XCTAssertEqual(state.petReveal?.selectedPetID, "mint")
    }

    func testDefaultWaitingPetParticipatesInRevealSelection() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let start = try date(clock: clock, year: 2026, month: 5, day: 19, hour: 9, minute: 25)
        let session = WorkSession(workDate: clock.workDate(for: start), workStartAt: start)
        var state = AppState(todaySession: session, gwStatus: .notConfigured, notificationSentForDate: nil)

        state.completePetReveal(
            for: session.workDate,
            availablePetIDs: ["mint"],
            picker: { candidates in
                candidates.contains(PetRevealState.defaultPetID)
                    ? PetRevealState.defaultPetID
                    : nil
            }
        )

        XCTAssertEqual(state.petReveal?.selectedPetID, PetRevealState.defaultPetID)
        XCTAssertEqual(
            state.petRevealDisplay(on: start, clock: clock, availablePetIDs: ["mint"]),
            .petVisible(PetRevealState.defaultPetID)
        )
    }

    func testMissingRegisteredPetsUseDefaultPetFallback() throws {
        var state = AppState.empty

        state.completePetReveal(for: "2026-05-19", availablePetIDs: [], picker: { _ in nil })

        XCTAssertEqual(state.petReveal?.selectedPetID, PetRevealState.defaultPetID)
    }

    func testInstalledLocalPetExcludesBundledPetsFromRevealSelection() throws {
        var state = AppState.empty

        state.completePetReveal(
            for: "2026-05-19",
            availablePetIDs: [LocalPetCatalog.legacyPetID, "mint", "specter"],
            picker: { _ in "mint" }
        )

        XCTAssertEqual(state.petReveal?.selectedPetID, LocalPetCatalog.legacyPetID)
    }

    func testMultipleLocalPetsStayRandomizedAmongThemselves() throws {
        var state = AppState.empty
        let availablePetIDs = [LocalPetCatalog.legacyPetID, "local-sprout", "mint"]

        state.completePetReveal(
            for: "2026-05-19",
            availablePetIDs: availablePetIDs,
            picker: { candidates in
                XCTAssertEqual(candidates, [LocalPetCatalog.legacyPetID, "local-sprout"])
                return "local-sprout"
            }
        )

        XCTAssertEqual(state.petReveal?.selectedPetID, "local-sprout")
    }

    func testPreviouslyRevealedBundledPetResolvesToLocalPetOnceInstalled() throws {
        let clock = WorkdayClock(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let start = try date(clock: clock, year: 2026, month: 5, day: 19, hour: 9, minute: 25)
        let session = WorkSession(workDate: clock.workDate(for: start), workStartAt: start)
        var state = AppState(todaySession: session, gwStatus: .notConfigured, notificationSentForDate: nil)
        state.petReveal = PetRevealState(workDate: session.workDate, isRevealed: true, selectedPetID: "mint")

        XCTAssertEqual(
            state.petRevealDisplay(
                on: start,
                clock: clock,
                availablePetIDs: [LocalPetCatalog.legacyPetID, "mint"]
            ),
            .petVisible(LocalPetCatalog.legacyPetID)
        )
    }

    private func date(
        clock: WorkdayClock,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) throws -> Date {
        try XCTUnwrap(DateComponents(
            calendar: clock.calendar,
            timeZone: clock.calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ).date)
    }
}
