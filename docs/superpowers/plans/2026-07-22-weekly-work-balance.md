# Weekly Work Balance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only weekly 40-hour balance to Mac Work Timer, subtract lunch overlap, preserve flex time for free use during the week, and show `오늘 퇴근`, `이번 주 여유`, and `오늘 다 쓰면` in the floating pet and menu.

**Architecture:** Keep GW parsing and time arithmetic in small `MacWorkTimerCore` units, cache the last valid weekly records in `AppState`, and use a separate `WKWebView` probe that reuses the existing website data store. `AppModel` derives an effective leave time from the cached records while retaining the unadjusted daily target for display.

**Tech Stack:** Swift 6.2, Foundation, SwiftUI, AppKit, WebKit, XCTest, Swift Package Manager

---

## File map

- Create `Sources/MacWorkTimerCore/WeeklyWorkModels.swift`: weekly record, cache, and summary value types.
- Create `Sources/MacWorkTimerCore/WeeklyAttendanceParser.swift`: turn GW table HTML or body text into typed weekly rows.
- Create `Sources/MacWorkTimerCore/WeeklyWorkBalanceCalculator.swift`: week boundaries, lunch overlap, credited hours, balance, and leave targets.
- Create `Sources/MacWorkTimerCore/WeeklyWorkCopyFormatter.swift`: friendly Korean balance copy.
- Modify `Sources/MacWorkTimerCore/Models.swift`: add optional weekly cache to `AppState` without breaking old state files.
- Modify `Sources/MacWorkTimerCore/SessionTracker.swift`: persist successful weekly refreshes.
- Create `Sources/MacWorkTimerApp/GWWeeklyWebSessionProbe.swift`: read-only WebKit navigation and table text extraction.
- Modify `Sources/MacWorkTimerApp/AppModel.swift`: refresh weekly data and expose normal/effective leave targets.
- Modify `Sources/MacWorkTimerApp/NotificationService.swift`: schedule against the effective leave target.
- Modify `Sources/MacWorkTimerApp/WorkPetView.swift`: render the three friendly weekly rows.
- Modify `Sources/MacWorkTimerApp/StatusBarController.swift`: expose the same values in the menu and tooltip.
- Modify `Sources/MacWorkTimerCore/PetPanelMetrics.swift`: make room for the three-line card.
- Add focused XCTest files under `Tests/MacWorkTimerCoreTests` for every core unit.

### Task 1: Weekly record models and GW table parser

**Files:**
- Create: `Sources/MacWorkTimerCore/WeeklyWorkModels.swift`
- Create: `Sources/MacWorkTimerCore/WeeklyAttendanceParser.swift`
- Test: `Tests/MacWorkTimerCoreTests/WeeklyAttendanceParserTests.swift`

- [ ] **Step 1: Write failing parser tests**

Create fixtures for the exact GW row shapes visible in the supplied screenshot, including two rows on the same date:

```swift
func testParsesCompletedAttendanceRowsFromTabbedBodyText() throws {
    let text = """
    일자\t요일\t출근시각\t출근등록방식\t퇴근시각\t퇴근등록방식\t근태항목\t근태구분
    2026-07-20\t월\t09:21\t세콤캡스연동\t18:44\t세콤캡스연동\t출퇴근\t정상
    2026-07-21\t화\t09:50\t세콤캡스연동\t18:36\t세콤캡스연동\t출퇴근\t정상
    """

    let records = WeeklyAttendanceParser().parse(text)

    XCTAssertEqual(records.count, 2)
    XCTAssertEqual(records[0].workDate, "2026-07-20")
    XCTAssertNotNil(records[0].checkInAt)
    XCTAssertNotNil(records[0].checkOutAt)
}

func testParsesAttendanceAndAfternoonLeaveAsSeparateRecords() {
    let text = """
    2026-07-10\t금\t09:21\t세콤캡스연동\t14:23\t세콤캡스연동\t출퇴근\t정상
    2026-07-10\t금\t\t\t\t\t법정휴가\t오후반차
    """

    let records = WeeklyAttendanceParser().parse(text)

    XCTAssertEqual(records.count, 2)
    XCTAssertEqual(records[1].creditedDuration, 4 * 60 * 60)
}
```

Also cover a blank current checkout, explicit `결근`, an HTML `<tr>/<td>` fixture, malformed time, and duplicate raw rows.

- [ ] **Step 2: Run the parser test and verify RED**

Run:

```bash
swift test --filter WeeklyAttendanceParserTests
```

Expected: compilation fails because `WeeklyAttendanceParser` and weekly model types do not exist.

- [ ] **Step 3: Add focused weekly record types**

Implement types shaped like:

```swift
public struct WeeklyAttendanceRecord: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case attendance
        case creditedLeave
        case explicitAbsence
    }

    public let workDate: String
    public let kind: Kind
    public let checkInAt: Date?
    public let checkOutAt: Date?
    public let creditedDuration: TimeInterval
    public let sourceText: String
}

public struct WeeklyAttendanceCache: Codable, Equatable, Sendable {
    public let weekStart: String
    public let fetchedAt: Date
    public let records: [WeeklyAttendanceRecord]
}
```

Use explicit field names rather than deriving meaning from `sourceText` outside the parser.

- [ ] **Step 4: Implement the minimal parser**

Normalize HTML row boundaries to newlines and cell boundaries to tabs. Build a row whenever a line begins with `yyyy-MM-dd`, parse the first two `HH:mm` tokens as check-in/check-out, and map leave text in this order:

```swift
if row.contains("오전반차") || row.contains("오후반차") {
    creditedDuration = 4 * 60 * 60
} else if row.contains("연차") || row.contains("휴가") || row.contains("공휴일") {
    creditedDuration = 8 * 60 * 60
} else if row.contains("결근") {
    creditedDuration = 0
}
```

Deduplicate identical normalized rows while preserving multiple distinct rows on the same date. Return an empty array when the expected table headers/date rows are absent; do not fabricate partial records.

- [ ] **Step 5: Run the parser tests and verify GREEN**

Run:

```bash
swift test --filter WeeklyAttendanceParserTests
```

Expected: all parser tests pass.

- [ ] **Step 6: Commit the parser slice**

```bash
git add Sources/MacWorkTimerCore/WeeklyWorkModels.swift Sources/MacWorkTimerCore/WeeklyAttendanceParser.swift Tests/MacWorkTimerCoreTests/WeeklyAttendanceParserTests.swift
git commit -m "Add GW weekly attendance parser"
```

### Task 2: Weekly balance calculator and friendly copy

**Files:**
- Create: `Sources/MacWorkTimerCore/WeeklyWorkBalanceCalculator.swift`
- Create: `Sources/MacWorkTimerCore/WeeklyWorkCopyFormatter.swift`
- Modify: `Sources/MacWorkTimerCore/WeeklyWorkModels.swift`
- Test: `Tests/MacWorkTimerCoreTests/WeeklyWorkBalanceCalculatorTests.swift`
- Test: `Tests/MacWorkTimerCoreTests/WeeklyWorkCopyFormatterTests.swift`

- [ ] **Step 1: Write failing arithmetic tests**

Use Seoul dates and assert the user examples exactly:

```swift
func testMondayWorkSubtractsLunchOverlap() throws {
    let record = attendance("2026-07-20", "09:21", "18:44")
    XCTAssertEqual(calculator.creditedDuration(for: [record]), 8 * 3600 + 23 * 60)
}

func testMondayAndTuesdayLeaveNineMinutesForWednesday() throws {
    let records = [
        attendance("2026-07-20", "09:21", "18:44"),
        attendance("2026-07-21", "09:50", "18:36")
    ]
    let session = WorkSession(workDate: "2026-07-22", workStartAt: date("2026-07-22", "09:35"))

    let summary = try XCTUnwrap(calculator.summary(records: records, todaySession: session, fetchedAt: date("2026-07-22", "10:00")))

    XCTAssertEqual(summary.balance, 9 * 60)
    XCTAssertEqual(summary.normalTargetAt, date("2026-07-22", "18:35"))
    XCTAssertEqual(summary.allFlexUsedTargetAt, date("2026-07-22", "18:26"))
}
```

Add tests for partial lunch overlap, no lunch overlap, half-day leave credit, explicit zero-hour absence, missing previous weekday, Monday week boundary, positive/zero/negative copy, and clamping `오늘 다 쓰면` no earlier than check-in.

- [ ] **Step 2: Run the calculator and copy tests and verify RED**

```bash
swift test --filter WeeklyWorkBalanceCalculatorTests
swift test --filter WeeklyWorkCopyFormatterTests
```

Expected: compilation fails because calculator, summary, and formatter do not exist.

- [ ] **Step 3: Implement the summary model and pure calculator**

Add:

```swift
public struct WeeklyWorkSummary: Equatable, Sendable {
    public let weekStart: String
    public let completedDuration: TimeInterval
    public let targetDurationThroughYesterday: TimeInterval
    public let balance: TimeInterval
    public let normalTargetAt: Date
    public let allFlexUsedTargetAt: Date
    public let fetchedAt: Date
    public let incompleteWorkDates: [String]

    public var isComplete: Bool { incompleteWorkDates.isEmpty }
}
```

The calculator must:

1. Determine Monday in `Asia/Seoul`.
2. Enumerate weekdays before `todaySession.workDate`.
3. Require at least one GW row for every elapsed weekday.
4. Sum gross attendance intervals per date.
5. Subtract at most the overlap with 12:00–13:00 per date.
6. Add explicit leave credit.
7. Compute `balance = completedDuration - elapsedWeekdays * 8h`.
8. Compute `allFlexUsedTargetAt = max(checkInAt, normalTargetAt - max(0, balance))` only when the summary is complete.

- [ ] **Step 4: Implement friendly copy formatting**

Expose stable testable values:

```swift
public enum WeeklyWorkCopyFormatter {
    public static func balanceLine(_ balance: TimeInterval) -> String {
        let minutes = Int(abs(balance) / 60)
        if minutes == 0 { return "이번 주 딱 맞아요" }
        if balance > 0 { return "이번 주 여유 +\(minutes)분" }
        return "이번 주 부족 \(minutes)분"
    }
}
```

Add hour-aware output such as `+1시간 12분`, while retaining the exact `+23분` copy.

- [ ] **Step 5: Run focused tests and verify GREEN**

```bash
swift test --filter WeeklyWorkBalanceCalculatorTests
swift test --filter WeeklyWorkCopyFormatterTests
```

Expected: all focused tests pass.

- [ ] **Step 6: Commit the calculator slice**

```bash
git add Sources/MacWorkTimerCore/WeeklyWorkModels.swift Sources/MacWorkTimerCore/WeeklyWorkBalanceCalculator.swift Sources/MacWorkTimerCore/WeeklyWorkCopyFormatter.swift Tests/MacWorkTimerCoreTests/WeeklyWorkBalanceCalculatorTests.swift Tests/MacWorkTimerCoreTests/WeeklyWorkCopyFormatterTests.swift
git commit -m "Add weekly work balance calculation"
```

### Task 3: Backward-compatible weekly cache persistence

**Files:**
- Modify: `Sources/MacWorkTimerCore/Models.swift`
- Modify: `Sources/MacWorkTimerCore/SessionTracker.swift`
- Modify: `Tests/MacWorkTimerCoreTests/StateStoreTests.swift`
- Modify: `Tests/MacWorkTimerCoreTests/SessionTrackerTests.swift`

- [ ] **Step 1: Write failing cache persistence tests**

Add a round-trip test and an old-state fixture test:

```swift
func testOldStateWithoutWeeklyCacheStillDecodes() throws {
    let json = #"{"gwStatus":{"notConfigured":{}},"notificationSentForDate":null,"todaySession":null}"#
    // Write JSON to the temporary StateStore file.
    XCTAssertNil(try store.load().weeklyAttendanceCache)
}

func testUpdateWeeklyAttendancePersistsLastSuccessfulCache() throws {
    let cache = WeeklyAttendanceCache(weekStart: "2026-07-20", fetchedAt: fetchedAt, records: records)
    let updated = try tracker.updateWeeklyAttendanceCache(cache)
    XCTAssertEqual(updated.weeklyAttendanceCache, cache)
    XCTAssertEqual(try store.load().weeklyAttendanceCache, cache)
}
```

- [ ] **Step 2: Run focused tests and verify RED**

```bash
swift test --filter StateStoreTests
swift test --filter SessionTrackerTests
```

Expected: compilation fails because `weeklyAttendanceCache` and the tracker update method do not exist.

- [ ] **Step 3: Add optional state and tracker update**

Add `weeklyAttendanceCache: WeeklyAttendanceCache? = nil` to `AppState.init` and `.empty`, and add:

```swift
@discardableResult
public func updateWeeklyAttendanceCache(_ cache: WeeklyAttendanceCache) throws -> AppState {
    var state = try store.load()
    state.weeklyAttendanceCache = cache
    try store.save(state)
    return state
}
```

Preserve the weekly cache across transient network/login failures. `clearSessionAndGWStatus`, which is used for an explicit logout, must clear the cache so a different account can never see the previous account's weekly rows.

- [ ] **Step 4: Run persistence tests and verify GREEN**

```bash
swift test --filter StateStoreTests
swift test --filter SessionTrackerTests
```

Expected: all state and tracker tests pass, including old JSON decoding.

- [ ] **Step 5: Commit persistence**

```bash
git add Sources/MacWorkTimerCore/Models.swift Sources/MacWorkTimerCore/SessionTracker.swift Tests/MacWorkTimerCoreTests/StateStoreTests.swift Tests/MacWorkTimerCoreTests/SessionTrackerTests.swift
git commit -m "Persist weekly attendance cache"
```

### Task 4: Read-only WebKit weekly attendance probe

**Files:**
- Create: `Sources/MacWorkTimerApp/GWWeeklyWebSessionProbe.swift`
- Modify: `Sources/MacWorkTimerApp/GWConfiguration.swift`
- Modify: `Sources/MacWorkTimerApp/AppModel.swift`
- Modify: `Sources/MacWorkTimerApp/GWWebLoginView.swift`
- Test: `Tests/MacWorkTimerCoreTests/WeeklyAttendanceParserTests.swift`

- [ ] **Step 1: Add parser fixtures matching DOM extraction**

Add a fixture where every table cell is on its own line and verify the parser groups cells between consecutive date tokens. This is the format produced by WebKit `innerText` on some table implementations.

- [ ] **Step 2: Run the DOM-shaped fixture and verify RED**

```bash
swift test --filter WeeklyAttendanceParserTests/testParsesCellsSplitAcrossLines
```

Expected: the parser returns no records until row grouping supports split cells.

- [ ] **Step 3: Make the parser accept both tabbed and split-cell rows**

Treat each date token as a new row boundary and append following cells until the next date. Re-run the entire parser suite to ensure same-date rows remain distinct.

- [ ] **Step 4: Add a WebKit probe that only navigates and reads**

Create a `@MainActor` probe with `WKWebsiteDataStore.default()` and a 15-second timeout. It must never evaluate form submission or attendance mutation scripts. Its JavaScript helpers should only collect text and click menu links:

```swift
private static let collectBodyText = #"""
(() => {
  const chunks = [];
  const visit = (win) => {
    try {
      if (win.document.body?.innerText) chunks.push(win.document.body.innerText);
      for (let index = 0; index < win.frames.length; index += 1) visit(win.frames[index]);
    } catch (_) {}
  };
  visit(window);
  return chunks.join('\n');
})()
"""#
```

On each completed navigation or delayed DOM check:

1. Collect all same-origin frame text.
2. If `WeeklyAttendanceParser` returns rows from the current Monday onward, complete successfully.
3. Otherwise click the exact visible menu label `인사/근태`.
4. Then click `개인근태현황`.
5. If neither target can be found before timeout, return a read-only failure without replacing cache.

- [ ] **Step 5: Wire weekly refresh after today attendance refresh/login**

`AppModel.refreshAttendance` and `applyAttendanceText` should trigger `refreshWeeklyAttendance()` after today status is resolved. A successful result builds:

```swift
let cache = WeeklyAttendanceCache(
    weekStart: calculator.weekStartString(containing: now),
    fetchedAt: now,
    records: records
)
state = try tracker.updateWeeklyAttendanceCache(cache)
```

Failure must leave `state.weeklyAttendanceCache` unchanged and must not replace the existing today status message with a noisy weekly error.

- [ ] **Step 6: Build the app target**

```bash
swift build --product MacWorkTimer
```

Expected: `Build complete!` with no Swift concurrency errors from WebKit callbacks.

- [ ] **Step 7: Commit the read-only integration**

```bash
git add Sources/MacWorkTimerApp/GWWeeklyWebSessionProbe.swift Sources/MacWorkTimerApp/GWConfiguration.swift Sources/MacWorkTimerApp/AppModel.swift Sources/MacWorkTimerApp/GWWebLoginView.swift Sources/MacWorkTimerCore/WeeklyAttendanceParser.swift Tests/MacWorkTimerCoreTests/WeeklyAttendanceParserTests.swift
git commit -m "Read weekly attendance from GW session"
```

### Task 5: Effective leave target and notification behavior

**Files:**
- Modify: `Sources/MacWorkTimerApp/AppModel.swift`
- Modify: `Sources/MacWorkTimerApp/NotificationService.swift`
- Modify: `Sources/MacWorkTimerCore/WorkdayClock.swift`
- Test: `Tests/MacWorkTimerCoreTests/WeeklyWorkBalanceCalculatorTests.swift`

- [ ] **Step 1: Add target fallback tests**

Test that complete weekly data uses `allFlexUsedTargetAt`, incomplete/missing cache uses the existing `session.targetAt`, and a stale cache from a different Monday is ignored.

- [ ] **Step 2: Run tests and verify RED**

```bash
swift test --filter WeeklyWorkBalanceCalculatorTests
```

Expected: new fallback assertions fail until summary validation is implemented.

- [ ] **Step 3: Expose normal and effective targets from AppModel**

Use computed properties:

```swift
var weeklySummary: WeeklyWorkSummary? {
    guard let session = currentSession,
          let cache = state.weeklyAttendanceCache,
          cache.weekStart == weeklyCalculator.weekStartString(containing: now) else { return nil }
    return weeklyCalculator.summary(records: cache.records, todaySession: session, fetchedAt: cache.fetchedAt)
}

var effectiveTargetAt: Date? {
    guard let session = currentSession else { return nil }
    guard let summary = weeklySummary, summary.isComplete else { return session.targetAt }
    return summary.allFlexUsedTargetAt
}
```

Calculate `remaining`, `progress`, pet mood, menu title, and notification action keys from `effectiveTargetAt`, but keep `normalTargetAt` available for the first UI row.

- [ ] **Step 4: Schedule notifications with the effective target**

Change notification methods to accept an explicit target date:

```swift
func scheduleCompletionNotification(for session: WorkSession, targetAt: Date, from now: Date) async
func deliverCompletionNotification(for session: WorkSession, targetAt: Date) async
```

Use `targetAt` for the trigger and action key. Keep the notification identifier per work date so refreshes replace, rather than duplicate, pending alerts.

- [ ] **Step 5: Run core tests and build app**

```bash
swift test
swift build --product MacWorkTimer
```

Expected: all tests pass and the app target builds.

- [ ] **Step 6: Commit target integration**

```bash
git add Sources/MacWorkTimerApp/AppModel.swift Sources/MacWorkTimerApp/NotificationService.swift Sources/MacWorkTimerCore/WorkdayClock.swift Tests/MacWorkTimerCoreTests/WeeklyWorkBalanceCalculatorTests.swift
git commit -m "Apply weekly flex time to leave target"
```

### Task 6: Friendly floating-pet and status-menu UI

**Files:**
- Modify: `Sources/MacWorkTimerApp/WorkPetView.swift`
- Modify: `Sources/MacWorkTimerApp/StatusBarController.swift`
- Modify: `Sources/MacWorkTimerCore/PetPanelMetrics.swift`
- Test: `Tests/MacWorkTimerCoreTests/PetPanelMetricsTests.swift`
- Test: `Tests/MacWorkTimerCoreTests/WeeklyWorkCopyFormatterTests.swift`

- [ ] **Step 1: Write layout and copy tests**

Add assertions that the three-line label leaves bottom clearance, and that exact copy remains friendly:

```swift
XCTAssertEqual(WeeklyWorkCopyFormatter.balanceLine(23 * 60), "이번 주 여유 +23분")
XCTAssertEqual(WeeklyWorkCopyFormatter.balanceLine(0), "이번 주 딱 맞아요")
XCTAssertEqual(WeeklyWorkCopyFormatter.balanceLine(-14 * 60), "이번 주 부족 14분")
XCTAssertLessThanOrEqual(PetPanelMetrics.localSpriteVisualBottom(labelLineCount: 3), PetPanelMetrics.height - PetPanelMetrics.minimumBottomMargin)
```

- [ ] **Step 2: Run UI-support tests and verify RED**

```bash
swift test --filter WeeklyWorkCopyFormatterTests
swift test --filter PetPanelMetricsTests
```

Expected: the three-line metric API and final copy do not yet exist.

- [ ] **Step 3: Implement the three-row card**

When a complete weekly summary is available, replace the old two-line leave label with aligned rows:

```swift
VStack(spacing: 2) {
    WeeklyTimeRow(label: "오늘 퇴근", value: time(summary.normalTargetAt))
    WeeklyTimeRow(label: balanceLabel, value: balanceValue)
    WeeklyTimeRow(label: "오늘 다 쓰면", value: time(summary.allFlexUsedTargetAt))
}
```

Do not include the word `기본`. When weekly data is unavailable, retain the existing leave-time/countdown display. Temporary pet-click messages can briefly replace the card and then return to the weekly rows.

- [ ] **Step 4: Add the same information to the status menu**

Rename the existing target row to `오늘 퇴근 HH:mm`, insert a weekly balance row, add `오늘 다 쓰면 HH:mm`, and add `마지막 확인 HH:mm` only for cached weekly data. Tooltip copy should use `오늘 퇴근` rather than `목표`.

- [ ] **Step 5: Adjust panel geometry**

Replace the boolean two-line metric with `labelLineCount`, increase panel height/offset only as much as required, and keep the existing agent-usage panel clear of the pet and bottom edge.

- [ ] **Step 6: Run focused tests and full test suite**

```bash
swift test --filter WeeklyWorkCopyFormatterTests
swift test --filter PetPanelMetricsTests
swift test
```

Expected: all tests pass.

- [ ] **Step 7: Commit UI**

```bash
git add Sources/MacWorkTimerApp/WorkPetView.swift Sources/MacWorkTimerApp/StatusBarController.swift Sources/MacWorkTimerCore/PetPanelMetrics.swift Tests/MacWorkTimerCoreTests/PetPanelMetricsTests.swift Tests/MacWorkTimerCoreTests/WeeklyWorkCopyFormatterTests.swift
git commit -m "Show friendly weekly flex time UI"
```

### Task 7: End-to-end build and visible verification

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-07-22-weekly-work-balance.md` (check completed boxes)

- [ ] **Step 1: Run all automated verification**

```bash
swift test
scripts/build_app.sh
plutil -lint "build/Mac Work Timer.app/Contents/Info.plist"
```

Expected: all tests pass, the bundle builds, and `plutil` reports `OK`.

- [ ] **Step 2: Verify the live GW route read-only with Playwright CLI**

Use the repository-provided command and never submit attendance mutations:

```bash
npm exec --yes --package=playwright -- node scripts/inspect_gw_login.mjs https://gw.evar.co.kr/gw/bizbox.do
```

Expected: the route is reachable and redirects to login when no reusable browser session is available. If authentication blocks automated inspection, record that as an external verification limitation; do not weaken parser/unit coverage.

- [ ] **Step 3: Launch the built app and verify it is visible**

```bash
open "build/Mac Work Timer.app"
```

Confirm the process is running, the floating pet is visible, and the status menu opens. With complete weekly data, confirm the exact three rows appear and the effective countdown agrees with `오늘 다 쓰면`.

- [ ] **Step 4: Capture visual evidence**

Use macOS screen capture for the native app, inspect the resulting PNG, and verify no truncation, overlap, or bottom clipping. Browser debugging, if needed, must remain Playwright CLI per `AGENTS.md`.

- [ ] **Step 5: Document behavior**

Update `README.md` to state that weekly records are read-only, lunch overlap is excluded, cached data may be shown with a last-confirmed time, and no attendance write API is called.

- [ ] **Step 6: Review the diff and commit final documentation**

```bash
git diff --check
git status --short
git diff --stat HEAD~6..HEAD
git add README.md docs/superpowers/plans/2026-07-22-weekly-work-balance.md
git commit -m "Document weekly work balance"
```

- [ ] **Step 7: Completion audit**

Map every design requirement to current evidence: core tests for arithmetic/parser/cache, build output for compilation, actual app screenshots for copy/layout, and Playwright output for the read-only GW route. Keep the goal active if any requirement lacks evidence.
