import Foundation

public enum AgentUsageProvider: String, Codable, Equatable, Sendable {
    case codex
    case claude

    public var displayName: String {
        switch self {
        case .codex:
            return "Codex"
        case .claude:
            return "Claude"
        }
    }
}

public enum AgentUsageSource: String, Codable, Equatable, Sendable {
    case codexSessionLog
    case claudeStatusLine
    case claudeHudCache
}

public struct AgentUsageSnapshot: Codable, Equatable, Sendable {
    public let provider: AgentUsageProvider
    public let usedPercent: Double
    public let windowMinutes: Int
    public let resetAt: Date?
    public let recordedAt: Date
    public let planName: String?
    public let source: AgentUsageSource

    public init(
        provider: AgentUsageProvider,
        usedPercent: Double,
        windowMinutes: Int,
        resetAt: Date?,
        recordedAt: Date,
        planName: String?,
        source: AgentUsageSource
    ) {
        self.provider = provider
        self.usedPercent = max(0, min(100, usedPercent))
        self.windowMinutes = windowMinutes
        self.resetAt = resetAt
        self.recordedAt = recordedAt
        self.planName = planName
        self.source = source
    }

    public var remainingPercent: Int {
        max(0, min(100, Int((100 - usedPercent).rounded())))
    }

    public func isFresh(at now: Date, freshnessInterval: TimeInterval = 30 * 60) -> Bool {
        guard now.timeIntervalSince(recordedAt) <= freshnessInterval else {
            return false
        }

        if let resetAt, resetAt <= now {
            return false
        }

        return true
    }
}

public struct AgentUsageCard: Equatable, Sendable, Identifiable {
    public let provider: AgentUsageProvider
    public let remainingPercent: Int
    public let primaryText: String
    public let secondaryText: String?
    public let resetAt: Date?
    public let isResetDominant: Bool

    public var id: AgentUsageProvider {
        provider
    }

    public init(
        provider: AgentUsageProvider,
        remainingPercent: Int,
        primaryText: String,
        secondaryText: String?,
        resetAt: Date?,
        isResetDominant: Bool
    ) {
        self.provider = provider
        self.remainingPercent = max(0, min(100, remainingPercent))
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.resetAt = resetAt
        self.isResetDominant = isResetDominant
    }
}

public enum CodexUsageParser {
    public static func snapshot(fromJSONL jsonl: String) -> AgentUsageSnapshot? {
        var latest: AgentUsageSnapshot?

        for line in jsonl.split(whereSeparator: \.isNewline) {
            guard let object = AgentUsageJSON.object(from: String(line)),
                  let snapshot = snapshot(fromCodexObject: object) else {
                continue
            }

            if latest == nil || snapshot.recordedAt >= latest!.recordedAt {
                latest = snapshot
            }
        }

        return latest
    }

    private static func snapshot(fromCodexObject object: [String: Any]) -> AgentUsageSnapshot? {
        guard let payload = object["payload"] as? [String: Any],
              let rateLimits = payload["rate_limits"] as? [String: Any],
              let primary = rateLimits["primary"] as? [String: Any],
              let usedPercent = AgentUsageJSON.double(primary["used_percent"]) else {
            return nil
        }

        let windowMinutes = AgentUsageJSON.int(primary["window_minutes"]) ?? 300
        let resetAt = AgentUsageJSON.double(primary["resets_at"]).map(Date.init(timeIntervalSince1970:))
        let recordedAt = AgentUsageJSON.isoDate(object["timestamp"] as? String) ?? Date()
        let planName = rateLimits["plan_type"] as? String

        return AgentUsageSnapshot(
            provider: .codex,
            usedPercent: usedPercent,
            windowMinutes: windowMinutes,
            resetAt: resetAt,
            recordedAt: recordedAt,
            planName: planName,
            source: .codexSessionLog
        )
    }
}

public enum ClaudeUsageParser {
    public static func snapshot(fromStatusLineJSON json: String, recordedAt: Date = Date()) -> AgentUsageSnapshot? {
        guard let object = AgentUsageJSON.object(from: json),
              let rateLimits = object["rate_limits"] as? [String: Any],
              let fiveHour = rateLimits["five_hour"] as? [String: Any],
              let usedPercent = AgentUsageJSON.double(fiveHour["used_percentage"]) else {
            return nil
        }

        return AgentUsageSnapshot(
            provider: .claude,
            usedPercent: usedPercent,
            windowMinutes: 300,
            resetAt: AgentUsageJSON.date(fiveHour["resets_at"]),
            recordedAt: recordedAt,
            planName: nil,
            source: .claudeStatusLine
        )
    }

    public static func snapshot(fromHudCacheJSON json: String, modifiedAt: Date) -> AgentUsageSnapshot? {
        guard let object = AgentUsageJSON.object(from: json),
              let data = object["data"] as? [String: Any],
              let usedPercent = AgentUsageJSON.double(data["fiveHour"]) else {
            return nil
        }

        return AgentUsageSnapshot(
            provider: .claude,
            usedPercent: usedPercent,
            windowMinutes: 300,
            resetAt: AgentUsageJSON.date(data["fiveHourResetAt"]),
            recordedAt: modifiedAt,
            planName: data["planName"] as? String,
            source: .claudeHudCache
        )
    }
}

public enum AgentUsageFormatter {
    public static func cards(
        _ snapshots: [AgentUsageSnapshot],
        now: Date,
        timeZone: TimeZone = TimeZone(identifier: "Asia/Seoul")!,
        freshnessInterval: TimeInterval = 30 * 60
    ) -> [AgentUsageCard] {
        let orderedProviders: [AgentUsageProvider] = [.codex, .claude]
        let newestByProvider = Dictionary(grouping: snapshots, by: \.provider).compactMapValues { items in
            items.max { $0.recordedAt < $1.recordedAt }
        }

        return orderedProviders.compactMap { provider in
            guard let snapshot = newestByProvider[provider],
                  isDisplayable(snapshot, now: now, freshnessInterval: freshnessInterval) else {
                return nil
            }

            return card(for: snapshot, timeZone: timeZone)
        }
    }

    public static func compactLine(
        _ snapshots: [AgentUsageSnapshot],
        now: Date,
        timeZone: TimeZone = TimeZone(identifier: "Asia/Seoul")!,
        freshnessInterval: TimeInterval = 30 * 60,
        includeMissingProviders: Bool = false
    ) -> String? {
        let orderedProviders: [AgentUsageProvider] = [.codex, .claude]
        let newestByProvider = Dictionary(grouping: snapshots, by: \.provider).compactMapValues { items in
            items.max { $0.recordedAt < $1.recordedAt }
        }

        let parts = orderedProviders.compactMap { provider -> String? in
            guard let snapshot = newestByProvider[provider] else {
                return includeMissingProviders ? "\(provider.displayName) 대기" : nil
            }
            return segment(for: snapshot, now: now, timeZone: timeZone, freshnessInterval: freshnessInterval)
        }

        guard !parts.isEmpty else {
            return nil
        }

        return parts.joined(separator: " / ")
    }

    private static func card(for snapshot: AgentUsageSnapshot, timeZone: TimeZone) -> AgentUsageCard {
        let resetText = snapshot.resetAt.map { resetTimeText($0, timeZone: timeZone) }
        if snapshot.usedPercent >= 100 {
            return AgentUsageCard(
                provider: snapshot.provider,
                remainingPercent: 0,
                primaryText: resetText.map { "리셋 \($0)" } ?? "리셋 대기",
                secondaryText: "0%",
                resetAt: snapshot.resetAt,
                isResetDominant: true
            )
        }

        return AgentUsageCard(
            provider: snapshot.provider,
            remainingPercent: snapshot.remainingPercent,
            primaryText: "\(snapshot.remainingPercent)%",
            secondaryText: resetText,
            resetAt: snapshot.resetAt,
            isResetDominant: false
        )
    }

    private static func segment(
        for snapshot: AgentUsageSnapshot,
        now: Date,
        timeZone: TimeZone,
        freshnessInterval: TimeInterval
    ) -> String {
        guard isDisplayable(snapshot, now: now, freshnessInterval: freshnessInterval) else {
            return "\(snapshot.provider.displayName) 대기"
        }

        let resetText = snapshot.resetAt.map { resetTimeText($0, timeZone: timeZone) }
        if snapshot.usedPercent >= 100 {
            if let resetText {
                return "\(snapshot.provider.displayName) 0% · 리셋 \(resetText)"
            }
            return "\(snapshot.provider.displayName) 0%"
        }

        if let resetText {
            return "\(snapshot.provider.displayName) \(snapshot.remainingPercent)% · \(resetText)"
        }

        return "\(snapshot.provider.displayName) \(snapshot.remainingPercent)%"
    }

    private static func isDisplayable(
        _ snapshot: AgentUsageSnapshot,
        now: Date,
        freshnessInterval: TimeInterval
    ) -> Bool {
        if snapshot.isFresh(at: now, freshnessInterval: freshnessInterval) {
            return true
        }

        guard let resetAt = snapshot.resetAt, resetAt > now else {
            return false
        }

        switch snapshot.source {
        case .codexSessionLog, .claudeStatusLine:
            return true
        case .claudeHudCache:
            return false
        }
    }

    private static func resetTimeText(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return String(
            format: "%02d:%02d",
            calendar.component(.hour, from: date),
            calendar.component(.minute, from: date)
        )
    }
}

public enum AgentUsageRefreshPolicy {
    public static func nextRefreshAt(
        snapshots: [AgentUsageSnapshot],
        lastRefreshAt: Date,
        defaultInterval: TimeInterval = 60,
        resetGraceInterval: TimeInterval = 5
    ) -> Date {
        let defaultRefreshAt = lastRefreshAt.addingTimeInterval(defaultInterval)
        let resetRefreshAt = snapshots
            .compactMap(\.resetAt)
            .filter { $0 > lastRefreshAt }
            .map { $0.addingTimeInterval(resetGraceInterval) }
            .min()

        guard let resetRefreshAt else {
            return defaultRefreshAt
        }

        return min(defaultRefreshAt, resetRefreshAt)
    }
}

public struct AgentUsageFileReader {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func readSnapshots(
        codexSessionsRoot: URL?,
        claudeStatusLineBridgeURL: URL?,
        claudeHudCacheURL: URL?
    ) -> [AgentUsageSnapshot] {
        [
            readCodexSnapshot(root: codexSessionsRoot),
            readClaudeSnapshot(bridgeURL: claudeStatusLineBridgeURL, hudCacheURL: claudeHudCacheURL)
        ].compactMap { $0 }
    }

    private func readCodexSnapshot(root: URL?) -> AgentUsageSnapshot? {
        guard let root,
              fileManager.fileExists(atPath: root.path),
              let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
              ) else {
            return nil
        }

        let files = enumerator.compactMap { entry -> (URL, Date)? in
            guard let url = entry as? URL,
                  url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]) else {
                return nil
            }
            return (url, values.contentModificationDate ?? .distantPast)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(120)

        return files.compactMap { url, _ in
            (try? String(contentsOf: url, encoding: .utf8))
                .flatMap(CodexUsageParser.snapshot(fromJSONL:))
        }
        .max { $0.recordedAt < $1.recordedAt }
    }

    private func readClaudeSnapshot(bridgeURL: URL?, hudCacheURL: URL?) -> AgentUsageSnapshot? {
        if let bridgeURL,
           fileManager.fileExists(atPath: bridgeURL.path),
           let json = try? String(contentsOf: bridgeURL, encoding: .utf8),
           let modifiedAt = modificationDate(for: bridgeURL),
           let snapshot = ClaudeUsageParser.snapshot(fromStatusLineJSON: json, recordedAt: modifiedAt) {
            return snapshot
        }

        if let hudCacheURL,
           fileManager.fileExists(atPath: hudCacheURL.path),
           let json = try? String(contentsOf: hudCacheURL, encoding: .utf8),
           let modifiedAt = modificationDate(for: hudCacheURL) {
            return ClaudeUsageParser.snapshot(fromHudCacheJSON: json, modifiedAt: modifiedAt)
        }

        return nil
    }

    private func modificationDate(for url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}

private enum AgentUsageJSON {
    static func object(from json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    static func double(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        if let value = value as? Int {
            return Double(value)
        }
        if let value = value as? String {
            return Double(value)
        }
        return nil
    }

    static func int(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? Double {
            return Int(value)
        }
        if let value = value as? String {
            return Int(value)
        }
        return nil
    }

    static func date(_ value: Any?) -> Date? {
        if let timestamp = double(value) {
            return Date(timeIntervalSince1970: timestamp)
        }

        return isoDate(value as? String)
    }

    static func isoDate(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
