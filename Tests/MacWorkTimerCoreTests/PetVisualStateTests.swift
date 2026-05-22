import XCTest
@testable import MacWorkTimerCore

final class PetVisualStateTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    func testDefaultLabelShowsRemainingTimeInKorean() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 5, day: 21, hour: 9).date)

        let state = PetVisualState.make(
            remaining: 8 * 3600 + 54 * 60,
            elapsed: 6 * 60,
            now: now,
            calendar: calendar,
            dragState: .idle,
            temporaryMessage: nil
        )

        XCTAssertEqual(state.label, "남은 8시간 54분")
        XCTAssertEqual(state.frameSetName, "working")
        XCTAssertEqual(state.labelTone, .neutral)
    }

    func testFinalSecondsUseSecondsLabelAndWarmTone() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 5, day: 21, hour: 17).date)

        let state = PetVisualState.make(
            remaining: 42,
            elapsed: 9 * 3600 - 42,
            now: now,
            calendar: calendar,
            dragState: .idle,
            temporaryMessage: nil
        )

        XCTAssertEqual(state.label, "퇴근까지 42초")
        XCTAssertEqual(state.frameSetName, "under5m")
        XCTAssertEqual(state.labelTone, .warm)
    }

    func testDoneShowsDoneLabelAndDoneFrame() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 5, day: 21, hour: 18, minute: 10).date)

        let state = PetVisualState.make(
            remaining: 0,
            elapsed: 9 * 3600,
            now: now,
            calendar: calendar,
            dragState: .idle,
            temporaryMessage: nil
        )

        XCTAssertEqual(state.label, "퇴근 가능")
        XCTAssertEqual(state.frameSetName, "done")
        XCTAssertEqual(state.labelTone, .done)
    }

    func testTemporaryClickMessageOverridesTimeLabelOnly() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 5, day: 21, hour: 15).date)

        let state = PetVisualState.make(
            remaining: 2 * 3600 + 15 * 60,
            elapsed: 6 * 3600,
            now: now,
            calendar: calendar,
            dragState: .idle,
            temporaryMessage: "조용히 가는 중"
        )

        XCTAssertEqual(state.label, "조용히 가는 중")
        XCTAssertEqual(state.frameSetName, "working-late")
    }

    func testDragStateOverridesFrameSet() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 5, day: 21, hour: 16).date)

        XCTAssertEqual(visualState(now: now, dragState: .pressed).frameSetName, "drag")
        XCTAssertEqual(visualState(now: now, dragState: .left).frameSetName, "drag-left")
        XCTAssertEqual(visualState(now: now, dragState: .right).frameSetName, "drag-right")
    }

    func testTimeOfDayAdjustsWorkingFrameSet() throws {
        let morning = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 5, day: 21, hour: 10).date)
        let afternoon = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 5, day: 21, hour: 13).date)
        let late = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 5, day: 21, hour: 16).date)

        XCTAssertEqual(visualState(now: morning, dragState: .idle).frameSetName, "working")
        XCTAssertEqual(visualState(now: afternoon, dragState: .idle).frameSetName, "working-afternoon")
        XCTAssertEqual(visualState(now: late, dragState: .idle).frameSetName, "working-late")
    }

    private func visualState(now: Date, dragState: PetDragState) -> PetVisualState {
        PetVisualState.make(
            remaining: 2 * 3600,
            elapsed: 7 * 3600,
            now: now,
            calendar: calendar,
            dragState: dragState,
            temporaryMessage: nil
        )
    }
}
