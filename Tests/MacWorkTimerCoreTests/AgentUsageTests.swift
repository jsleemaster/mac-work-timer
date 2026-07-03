import XCTest
@testable import MacWorkTimerCore

final class AgentUsageTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    func testCodexParserReadsLatestFiveHourRateLimitFromJSONL() throws {
        let jsonl = """
        {"timestamp":"2026-06-16T04:40:55.526Z","type":"event_msg","payload":{"rate_limits":{"primary":{"used_percent":7.0,"window_minutes":300,"resets_at":1781588855},"secondary":{"used_percent":10.0,"window_minutes":10080,"resets_at":1781744486},"plan_type":"pro"}}}
        {"timestamp":"2026-06-16T04:41:19.153Z","type":"event_msg","payload":{"rate_limits":{"primary":{"used_percent":8.0,"window_minutes":300,"resets_at":1781588855},"secondary":{"used_percent":10.0,"window_minutes":10080,"resets_at":1781744486},"plan_type":"pro"}}}
        """

        let snapshot = try XCTUnwrap(CodexUsageParser.snapshot(fromJSONL: jsonl))

        XCTAssertEqual(snapshot.provider, .codex)
        XCTAssertEqual(snapshot.usedPercent, 8)
        XCTAssertEqual(snapshot.remainingPercent, 92)
        XCTAssertEqual(snapshot.windowMinutes, 300)
        XCTAssertEqual(snapshot.windowKind, .fiveHour)
        XCTAssertEqual(snapshot.resetAt, Date(timeIntervalSince1970: 1_781_588_855))
        XCTAssertEqual(snapshot.planName, "pro")
        XCTAssertEqual(snapshot.source, .codexSessionLog)
    }

    func testCodexParserPrefersLimitedWeeklySecondaryWindow() throws {
        let jsonl = """
        {"timestamp":"2026-06-16T04:41:19.153Z","type":"event_msg","payload":{"rate_limits":{"primary":{"used_percent":12.0,"window_minutes":300,"resets_at":1781588855},"secondary":{"used_percent":100.0,"window_minutes":10080,"resets_at":1781744486},"plan_type":"pro"}}}
        """

        let snapshot = try XCTUnwrap(CodexUsageParser.snapshot(fromJSONL: jsonl))

        XCTAssertEqual(snapshot.provider, .codex)
        XCTAssertEqual(snapshot.usedPercent, 100)
        XCTAssertEqual(snapshot.remainingPercent, 0)
        XCTAssertEqual(snapshot.windowMinutes, 10080)
        XCTAssertEqual(snapshot.windowKind, .weekly)
        XCTAssertEqual(snapshot.resetAt, Date(timeIntervalSince1970: 1_781_744_486))
    }

    func testClaudeStatusLineParserReadsFiveHourUsage() throws {
        let json = """
        {
          "rate_limits": {
            "five_hour": {
              "used_percentage": 54,
              "resets_at": "2026-06-16T09:00:00.157Z"
            }
          }
        }
        """

        let snapshot = try XCTUnwrap(ClaudeUsageParser.snapshot(fromStatusLineJSON: json))
        let resetAt = try XCTUnwrap(snapshot.resetAt)

        XCTAssertEqual(snapshot.provider, .claude)
        XCTAssertEqual(snapshot.usedPercent, 54)
        XCTAssertEqual(snapshot.remainingPercent, 46)
        XCTAssertEqual(snapshot.windowMinutes, 300)
        XCTAssertEqual(snapshot.windowKind, .fiveHour)
        XCTAssertEqual(resetAt.timeIntervalSince1970, 1_781_600_400.157, accuracy: 0.001)
        XCTAssertEqual(snapshot.source, .claudeStatusLine)
    }

    func testClaudeStatusLineParserPrefersLimitedWeeklyWindow() throws {
        let json = """
        {
          "rate_limits": {
            "five_hour": {
              "used_percentage": 54,
              "resets_at": "2026-06-16T09:00:00.157Z"
            },
            "weekly": {
              "used_percentage": 100,
              "resets_at": "2026-06-18T09:00:00.000Z"
            }
          }
        }
        """

        let snapshot = try XCTUnwrap(ClaudeUsageParser.snapshot(fromStatusLineJSON: json))

        XCTAssertEqual(snapshot.usedPercent, 100)
        XCTAssertEqual(snapshot.windowMinutes, 10080)
        XCTAssertEqual(snapshot.windowKind, .weekly)
    }

    func testClaudeStatusLineParserAcceptsNumericResetTimestamp() throws {
        let json = """
        {
          "rate_limits": {
            "five_hour": {
              "used_percentage": 100,
              "resets_at": 1781588400
            }
          }
        }
        """

        let snapshot = try XCTUnwrap(ClaudeUsageParser.snapshot(fromStatusLineJSON: json))

        XCTAssertEqual(snapshot.usedPercent, 100)
        XCTAssertEqual(snapshot.resetAt, Date(timeIntervalSince1970: 1_781_588_400))
    }

    func testClaudeHudCacheParserReadsFreshCacheShape() throws {
        let modifiedAt = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 13, minute: 10).date)
        let json = """
        {
          "data": {
            "planName": "Max",
            "fiveHour": 73,
            "fiveHourResetAt": "2026-06-16T09:00:00.157Z"
          }
        }
        """

        let snapshot = try XCTUnwrap(ClaudeUsageParser.snapshot(fromHudCacheJSON: json, modifiedAt: modifiedAt))

        XCTAssertEqual(snapshot.provider, .claude)
        XCTAssertEqual(snapshot.usedPercent, 73)
        XCTAssertEqual(snapshot.remainingPercent, 27)
        XCTAssertEqual(snapshot.planName, "Max")
        XCTAssertEqual(snapshot.recordedAt, modifiedAt)
        XCTAssertEqual(snapshot.source, .claudeHudCache)
    }

    func testCompactLineHidesFreshUsageWhenNoLimitIsHit() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 13, minute: 45).date)
        let reset = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 14, minute: 47).date)
        let snapshots = [
            AgentUsageSnapshot(
                provider: .codex,
                usedPercent: 7,
                windowMinutes: 300,
                resetAt: reset,
                recordedAt: now,
                planName: "pro",
                source: .codexSessionLog
            ),
            AgentUsageSnapshot(
                provider: .claude,
                usedPercent: 54,
                windowMinutes: 300,
                resetAt: reset,
                recordedAt: now,
                planName: "Max",
                source: .claudeStatusLine
            )
        ]

        let line = AgentUsageFormatter.compactLine(snapshots, now: now, timeZone: calendar.timeZone)

        XCTAssertNil(line)
    }

    func testCompactLineShowsLimitAndResetRemainingPercentWhenUsageIsFull() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 13, minute: 45).date)
        let reset = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 14, minute: 47).date)
        let snapshot = AgentUsageSnapshot(
            provider: .codex,
            usedPercent: 100,
            windowMinutes: 300,
            resetAt: reset,
            recordedAt: now,
            planName: nil,
            source: .codexSessionLog
        )

        let line = AgentUsageFormatter.compactLine([snapshot], now: now, timeZone: calendar.timeZone)

        XCTAssertEqual(line, "Codex 초기화 까지 21% · 14:47")
    }

    func testCompactLineHidesStaleProviderWhenNoLimitIsHit() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 13, minute: 45).date)
        let recordedAt = now.addingTimeInterval(-31 * 60)
        let reset = now.addingTimeInterval(60 * 60)
        let snapshot = AgentUsageSnapshot(
            provider: .claude,
            usedPercent: 50,
            windowMinutes: 300,
            resetAt: reset,
            recordedAt: recordedAt,
            planName: "Max",
            source: .claudeHudCache
        )

        let line = AgentUsageFormatter.compactLine([snapshot], now: now, timeZone: calendar.timeZone, freshnessInterval: 30 * 60)

        XCTAssertNil(line)
    }

    func testUsageCardsHideMissingAndStaleProviders() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 13, minute: 45).date)
        let stale = AgentUsageSnapshot(
            provider: .claude,
            usedPercent: 50,
            windowMinutes: 300,
            resetAt: now.addingTimeInterval(60 * 60),
            recordedAt: now.addingTimeInterval(-31 * 60),
            planName: "Max",
            source: .claudeHudCache
        )

        let cards = AgentUsageFormatter.cards(
            [stale],
            now: now,
            timeZone: calendar.timeZone,
            freshnessInterval: 30 * 60
        )

        XCTAssertTrue(cards.isEmpty)
    }

    func testUsageCardsKeepStaleSnapshotVisibleWhenResetIsStillFuture() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 14, minute: 34).date)
        let reset = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 14, minute: 40).date)
        let snapshot = AgentUsageSnapshot(
            provider: .claude,
            usedPercent: 100,
            windowMinutes: 300,
            resetAt: reset,
            recordedAt: now.addingTimeInterval(-37 * 60),
            planName: "Max",
            source: .claudeStatusLine
        )

        let cards = AgentUsageFormatter.cards(
            [snapshot],
            now: now,
            timeZone: calendar.timeZone,
            freshnessInterval: 30 * 60
        )

        XCTAssertEqual(cards.first?.provider, .claude)
        XCTAssertEqual(cards.first?.remainingPercent, 2)
        XCTAssertEqual(cards.first?.primaryText, "초기화 까지 2%")
        XCTAssertEqual(cards.first?.secondaryText, "14:40")
    }

    func testCompactLineKeepsStaleStatusLineVisibleWhenResetIsStillFuture() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 14, minute: 34).date)
        let reset = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 14, minute: 40).date)
        let snapshot = AgentUsageSnapshot(
            provider: .claude,
            usedPercent: 100,
            windowMinutes: 300,
            resetAt: reset,
            recordedAt: now.addingTimeInterval(-37 * 60),
            planName: "Max",
            source: .claudeStatusLine
        )

        let line = AgentUsageFormatter.compactLine(
            [snapshot],
            now: now,
            timeZone: calendar.timeZone,
            freshnessInterval: 30 * 60
        )

        XCTAssertEqual(line, "Claude 초기화 까지 2% · 14:40")
    }

    func testUsageCardsHideProviderWhenNoLimitIsHit() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 13, minute: 45).date)
        let reset = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 14, minute: 47).date)
        let snapshot = AgentUsageSnapshot(
            provider: .codex,
            usedPercent: 14,
            windowMinutes: 300,
            resetAt: reset,
            recordedAt: now,
            planName: "pro",
            source: .codexSessionLog
        )

        let cards = AgentUsageFormatter.cards([snapshot], now: now, timeZone: calendar.timeZone)

        XCTAssertTrue(cards.isEmpty)
    }

    func testUsageCardsPrioritizeResetRemainingPercentWhenUsageIsFull() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 13, minute: 45).date)
        let reset = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 14, minute: 40).date)
        let snapshot = AgentUsageSnapshot(
            provider: .claude,
            usedPercent: 100,
            windowMinutes: 300,
            resetAt: reset,
            recordedAt: now,
            planName: "Max",
            source: .claudeStatusLine
        )

        let cards = AgentUsageFormatter.cards([snapshot], now: now, timeZone: calendar.timeZone)

        XCTAssertEqual(cards, [
            AgentUsageCard(
                provider: .claude,
                remainingPercent: 19,
                primaryText: "초기화 까지 19%",
                secondaryText: "14:40",
                resetAt: reset,
                isResetDominant: true
            )
        ])
    }

    func testRefreshPolicyUsesEarliestResetAfterLastRefreshBeforeDefaultPolling() throws {
        let lastRefresh = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 13, minute: 45).date)
        let reset = lastRefresh.addingTimeInterval(20)
        let snapshot = AgentUsageSnapshot(
            provider: .claude,
            usedPercent: 100,
            windowMinutes: 300,
            resetAt: reset,
            recordedAt: lastRefresh,
            planName: "Max",
            source: .claudeStatusLine
        )

        let next = AgentUsageRefreshPolicy.nextRefreshAt(
            snapshots: [snapshot],
            lastRefreshAt: lastRefresh,
            defaultInterval: 60,
            resetGraceInterval: 5
        )

        XCTAssertEqual(next, reset.addingTimeInterval(5))
    }

    func testRefreshPolicyFallsBackToDefaultPollingWithoutFutureReset() throws {
        let lastRefresh = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 13, minute: 45).date)
        let snapshot = AgentUsageSnapshot(
            provider: .codex,
            usedPercent: 30,
            windowMinutes: 300,
            resetAt: lastRefresh.addingTimeInterval(-5),
            recordedAt: lastRefresh,
            planName: "pro",
            source: .codexSessionLog
        )

        let next = AgentUsageRefreshPolicy.nextRefreshAt(
            snapshots: [snapshot],
            lastRefreshAt: lastRefresh,
            defaultInterval: 60,
            resetGraceInterval: 5
        )

        XCTAssertEqual(next, lastRefresh.addingTimeInterval(60))
    }

    func testRefreshPolicyDefaultPollingIsFiveMinutes() throws {
        let lastRefresh = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 13, minute: 45).date)

        let next = AgentUsageRefreshPolicy.nextRefreshAt(
            snapshots: [],
            lastRefreshAt: lastRefresh
        )

        XCTAssertEqual(next, lastRefresh.addingTimeInterval(5 * 60))
    }

    func testCompactLineCanIncludeMissingProvidersAsWaiting() throws {
        let now = try XCTUnwrap(DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 16, hour: 13, minute: 45).date)
        let reset = now.addingTimeInterval(60 * 60)
        let snapshot = AgentUsageSnapshot(
            provider: .codex,
            usedPercent: 7,
            windowMinutes: 300,
            resetAt: reset,
            recordedAt: now,
            planName: "pro",
            source: .codexSessionLog
        )

        let line = AgentUsageFormatter.compactLine(
            [snapshot],
            now: now,
            timeZone: calendar.timeZone,
            includeMissingProviders: true
        )

        XCTAssertEqual(line, "Claude 대기")
    }

    func testFileReaderReadsCodexSessionLogsAndClaudeBridgeFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacWorkTimerAgentUsageTests-\(UUID().uuidString)", isDirectory: true)
        let codexRoot = root.appendingPathComponent("codex", isDirectory: true)
        let codexDay = codexRoot.appendingPathComponent("2026/06/16", isDirectory: true)
        let claudeBridgeURL = root.appendingPathComponent("claude.json")
        try FileManager.default.createDirectory(at: codexDay, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try """
        {"timestamp":"2026-06-16T04:40:55.526Z","type":"event_msg","payload":{"rate_limits":{"primary":{"used_percent":7.0,"window_minutes":300,"resets_at":1781588855},"plan_type":"pro"}}}
        """.write(to: codexDay.appendingPathComponent("rollout-old.jsonl"), atomically: true, encoding: .utf8)
        try """
        {"timestamp":"2026-06-16T04:42:00.000Z","type":"event_msg","payload":{"rate_limits":{"primary":{"used_percent":9.0,"window_minutes":300,"resets_at":1781588855},"plan_type":"pro"}}}
        """.write(to: codexDay.appendingPathComponent("rollout-new.jsonl"), atomically: true, encoding: .utf8)
        try """
        {"rate_limits":{"five_hour":{"used_percentage":54,"resets_at":"2026-06-16T09:00:00.157Z"}}}
        """.write(to: claudeBridgeURL, atomically: true, encoding: .utf8)

        let snapshots = AgentUsageFileReader().readSnapshots(
            codexSessionsRoot: codexRoot,
            claudeStatusLineBridgeURL: claudeBridgeURL,
            claudeHudCacheURL: nil
        )

        XCTAssertEqual(snapshots.first(where: { $0.provider == .codex })?.usedPercent, 9)
        XCTAssertEqual(snapshots.first(where: { $0.provider == .claude })?.usedPercent, 54)
        XCTAssertEqual(snapshots.count, 2)
    }

    func testFileReaderReadsCodexRateLimitFromTailOfLargeSessionLog() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacWorkTimerAgentUsageTailTests-\(UUID().uuidString)", isDirectory: true)
        let codexRoot = root.appendingPathComponent("codex", isDirectory: true)
        let codexDay = codexRoot.appendingPathComponent("2026/06/16", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDay, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let largePrefix = String(repeating: #"{"timestamp":"2026-06-16T04:00:00.000Z","type":"noise"}"# + "\n", count: 200)
        let latest = #"{"timestamp":"2026-06-16T04:42:00.000Z","type":"event_msg","payload":{"rate_limits":{"primary":{"used_percent":99.0,"window_minutes":300,"resets_at":1781588855},"plan_type":"pro"}}}"#
        try (largePrefix + latest + "\n").write(
            to: codexDay.appendingPathComponent("rollout-large.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let snapshots = AgentUsageFileReader(codexTailByteLimit: 512).readSnapshots(
            codexSessionsRoot: codexRoot,
            claudeStatusLineBridgeURL: nil,
            claudeHudCacheURL: nil
        )

        XCTAssertEqual(snapshots.first?.provider, .codex)
        XCTAssertEqual(snapshots.first?.usedPercent, 99)
    }
}
