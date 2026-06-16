# Agent Limit Only UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show Codex/Claude AI usage UI only when a 5-hour or weekly limit is fully exhausted, with reset progress as the primary value.

**Architecture:** Extend `AgentUsageSnapshot` with a rate-limit window kind and parse Codex secondary weekly limits. Keep all filtering inside `AgentUsageFormatter` so the pet view and menu bar continue to consume `agentUsageCards` and `agentUsageLine` without duplicating limit logic.

**Tech Stack:** Swift 6, SwiftPM XCTest, SwiftUI/AppKit.

---

### Task 1: Rate-Limit Window Model And Parsing

**Files:**
- Modify: `Sources/MacWorkTimerCore/AgentUsage.swift`
- Modify: `Tests/MacWorkTimerCoreTests/AgentUsageTests.swift`

- [ ] Add failing tests for Codex weekly parsing and non-limited snapshots being hidden.
- [ ] Add `AgentUsageWindowKind` with `.fiveHour` and `.weekly`.
- [ ] Add `windowKind` to `AgentUsageSnapshot`, defaulting existing tests to `.fiveHour`.
- [ ] Parse Codex primary as `.fiveHour` and secondary as `.weekly`; keep the most relevant exhausted window.
- [ ] Verify targeted tests pass.

### Task 2: Limit-Only Formatting

**Files:**
- Modify: `Sources/MacWorkTimerCore/AgentUsage.swift`
- Modify: `Tests/MacWorkTimerCoreTests/AgentUsageTests.swift`

- [ ] Add failing tests proving cards/compact line hide non-100% snapshots.
- [ ] Format exhausted cards with reset progress as the primary value, for example `초기화 3%`, and show the exact reset time as secondary text.
- [ ] Keep expired or stale non-resettable values hidden.
- [ ] Verify all AgentUsage tests pass.

### Task 3: UI Copy And Documentation

**Files:**
- Modify: `Sources/MacWorkTimerApp/WorkPetView.swift`
- Modify: `Sources/MacWorkTimerApp/StatusBarController.swift`
- Modify: `README.md`

- [ ] Ensure card text prioritizes limit reason and reset time.
- [ ] Update menu item wording from usage to limit state.
- [ ] Update README to state the indicator appears only when a local AI limit is hit.
- [ ] Run `swift test`, `./scripts/build_app.sh`, secret scan, commit, and push to the existing PR branch.
