import AppKit
import Foundation
import MacWorkTimerCore
import SwiftUI

@MainActor
final class AppModel: NSObject, ObservableObject {
    static let shared = AppModel()

    @Published private(set) var now = Date()
    @Published var state: AppState = .empty
    @Published var statusMessage: String?
    @Published var launchAtLogin = false
    @Published var isLoggingIn = false
    @Published private(set) var agentUsageSnapshots: [AgentUsageSnapshot] = []

    private let clock: WorkdayClock
    private let tracker: SessionTracker
    private let credentialStore: KeychainCredentialStore
    private let gwClient: GWClient
    private let activityStartProvider: SystemActivityStartProvider
    private let webSessionProbe = GWWebSessionProbe()
    private let notificationService: NotificationService
    private let loginItemsController: LoginItemsController
    private let agentUsageReader: AgentUsageFileReader
    private var timer: Timer?
    private var lastAgentUsageRefreshAt: Date?
    private var notificationTask: Task<Void, Never>?
    private var lastNotificationActionKey: String?
    private var attendanceTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []

    override init() {
        let clock = WorkdayClock()
        let tracker = SessionTracker(clock: clock)
        let credentialStore = KeychainCredentialStore(account: GWConfiguration.credentialAccount)

        self.clock = clock
        self.tracker = tracker
        self.credentialStore = credentialStore
        self.gwClient = GWClient(baseURL: GWConfiguration.baseURL, credentialStore: credentialStore)
        self.activityStartProvider = SystemActivityStartProvider(clock: clock)
        self.notificationService = NotificationService()
        self.loginItemsController = LoginItemsController()
        self.agentUsageReader = AgentUsageFileReader()
        self.launchAtLogin = loginItemsController.isEnabled

        super.init()

        loadStoredState()
        refreshAgentUsage(force: true)
        startClock()
        observeSystemActivity()

        Task {
            _ = await notificationService.requestAuthorization()
            refreshAttendance()
            updateNotificationIfNeeded(force: true)
        }
    }

    var currentSession: WorkSession? {
        state.currentSession(on: now, clock: clock)
    }

    var elapsed: TimeInterval? {
        guard let currentSession else {
            return nil
        }
        return max(0, now.timeIntervalSince(currentSession.workStartAt))
    }

    var remaining: TimeInterval? {
        guard let currentSession else {
            return nil
        }
        return clock.remainingTime(for: currentSession, at: now)
    }

    var progress: Double {
        guard let elapsed, let currentSession else {
            return 0
        }
        return min(1, max(0, elapsed / currentSession.workdayDuration))
    }

    var workdayMode: WorkdayMode {
        state.workdayMode(on: now, clock: clock)
    }

    func petRevealDisplay(availablePetIDs: [String]) -> PetRevealDisplay {
        state.petRevealDisplay(on: now, availablePetIDs: availablePetIDs)
    }

    func completePetReveal(availablePetIDs: [String]) {
        guard let workDate = currentSession?.workDate else {
            return
        }

        do {
            state = try tracker.completePetReveal(for: workDate, availablePetIDs: availablePetIDs)
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    var menuBarTitle: String {
        guard let remaining else {
            return "Work Timer"
        }
        return MenuBarStatusFormatter.title(remaining: remaining)
    }

    var agentUsageLine: String? {
        AgentUsageFormatter.compactLine(
            agentUsageSnapshots,
            now: now,
            includeMissingProviders: false
        )
    }

    var agentUsageCards: [AgentUsageCard] {
        AgentUsageFormatter.cards(agentUsageSnapshots, now: now)
    }

    func loadStoredState() {
        do {
            state = try tracker.load()
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func refreshAttendance(force: Bool = false, allowWebSessionProbe: Bool = false) {
        guard force || !isLoggingIn else {
            return
        }

        startOrResumeLocalSession()

        let hasStoredSession = currentSession != nil
        state.gwStatus = .checking
        isLoggingIn = true
        statusMessage = hasStoredSession ? nil : "GW 로그인 상태를 확인 중입니다."

        attendanceTask?.cancel()
        attendanceTask = Task { [weak self] in
            guard let self else {
                return
            }

            let status = await gwClient.refreshTodayStatus()
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self.handleCredentialLoginStatus(
                    status,
                    hasStoredSession: hasStoredSession,
                    allowWebSessionProbe: allowWebSessionProbe
                )
            }
        }
    }

    private func handleCredentialLoginStatus(
        _ status: GWStatus,
        hasStoredSession: Bool,
        allowWebSessionProbe: Bool
    ) {
        switch status {
        case .attendance, .checking, .readOnlySummary:
            applyAttendanceStatus(status, hasStoredSession: hasStoredSession)
        case .notConfigured, .requiresWebLogin, .failed:
            if allowWebSessionProbe {
                probeExistingWebSession(hasStoredSession: hasStoredSession, credentialStatus: status)
            } else {
                applyAttendanceStatus(status, hasStoredSession: hasStoredSession)
            }
        }
    }

    private func probeExistingWebSession(hasStoredSession: Bool, credentialStatus: GWStatus) {
        webSessionProbe.refresh { [weak self] webStatus in
            guard let self else {
                return
            }

            let resolvedStatus: GWStatus
            switch webStatus {
            case .requiresWebLogin where credentialStatus != .notConfigured:
                resolvedStatus = credentialStatus
            default:
                resolvedStatus = webStatus
            }

            self.applyAttendanceStatus(resolvedStatus, hasStoredSession: hasStoredSession)
        }
    }

    private func applyAttendanceStatus(_ status: GWStatus, hasStoredSession: Bool) {
        do {
            switch status {
            case .attendance(let record):
                state = try tracker.applyAttendance(record)
                statusMessage = nil
            default:
                state = try tracker.updateGWStatus(status)
                statusMessage = hasStoredSession ? nil : message(for: status)
            }
        } catch {
            state.gwStatus = status
            statusMessage = hasStoredSession ? nil : error.localizedDescription
        }

        attendanceTask = nil
        isLoggingIn = false
        updateNotificationIfNeeded(force: true)
    }

    private func startOrResumeLocalSession() {
        do {
            state = try tracker.startOrResume(now: now, preferredStart: activityStartProvider.preferredStart(for: now))
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func applyAttendanceText(_ text: String) {
        let status = GWWebSessionInterpreter.status(from: text)

        do {
            switch status {
            case .attendance(let record):
                state = try tracker.applyAttendance(record)
                statusMessage = nil
            default:
                state = try tracker.updateGWStatus(status)
                statusMessage = message(for: status)
            }
            updateNotificationIfNeeded(force: true)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func logout() {
        do {
            try credentialStore.deleteCredentials()
            state = try tracker.clearSessionAndGWStatus()
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItemsController.setEnabled(enabled)
            launchAtLogin = loginItemsController.isEnabled
            statusMessage = launchAtLogin ? "로그인 시 자동 실행을 켰습니다." : "로그인 시 자동 실행을 껐습니다."
        } catch {
            launchAtLogin = loginItemsController.isEnabled
            statusMessage = error.localizedDescription
        }
    }

    func setWorkdayMode(_ mode: WorkdayMode) {
        let workDate = currentSession?.workDate ?? clock.workDate(for: now)
        do {
            state = try tracker.setWorkdayMode(mode, for: workDate)
            statusMessage = "\(mode.title) 기준으로 계산합니다."
            updateNotificationIfNeeded(force: true)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func startClock() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        now = Date()
        refreshAgentUsageIfNeeded()
        updateNotificationIfNeeded()
    }

    private func refreshAgentUsageIfNeeded() {
        guard let lastAgentUsageRefreshAt else {
            refreshAgentUsage(force: true)
            return
        }

        let nextRefreshAt = AgentUsageRefreshPolicy.nextRefreshAt(
            snapshots: agentUsageSnapshots,
            lastRefreshAt: lastAgentUsageRefreshAt
        )

        guard now >= nextRefreshAt else {
            return
        }

        refreshAgentUsage(force: true)
    }

    private func refreshAgentUsage(force: Bool) {
        if !force, let lastAgentUsageRefreshAt, now.timeIntervalSince(lastAgentUsageRefreshAt) < 60 {
            return
        }

        lastAgentUsageRefreshAt = now
        agentUsageSnapshots = agentUsageReader.readSnapshots(
            codexSessionsRoot: AgentUsagePaths.codexSessionsRoot,
            claudeStatusLineBridgeURL: AgentUsagePaths.claudeStatusLineBridgeURL,
            claudeHudCacheURL: AgentUsagePaths.claudeHudCacheURL
        )
    }

    private func observeSystemActivity() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        notificationObservers.append(
            workspaceCenter.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshAttendance()
                }
            }
        )
        notificationObservers.append(
            workspaceCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshAttendance()
                }
            }
        )
        notificationObservers.append(
            NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.loadStoredState()
                    self?.refreshAgentUsage(force: true)
                }
            }
        )
    }

    private func updateNotificationIfNeeded(force: Bool = false) {
        guard let session = currentSession else {
            lastNotificationActionKey = nil
            notificationTask?.cancel()
            notificationTask = nil
            return
        }

        let targetKey = "\(session.workDate)|\(session.targetAt.timeIntervalSince1970)"

        if clock.isComplete(session, at: now) {
            guard state.notificationSentForDate != session.workDate else {
                return
            }

            let actionKey = "deliver|\(targetKey)"
            guard force || lastNotificationActionKey != actionKey else {
                return
            }

            lastNotificationActionKey = actionKey
            notificationTask?.cancel()
            notificationTask = Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                await notificationService.deliverCompletionNotification(for: session)
                guard !Task.isCancelled else {
                    return
                }

                do {
                    state = try tracker.markNotificationSent(for: session.workDate)
                    lastNotificationActionKey = "delivered|\(session.workDate)"
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
            return
        }

        let actionKey = "schedule|\(targetKey)"
        guard force || lastNotificationActionKey != actionKey else {
            return
        }

        lastNotificationActionKey = actionKey
        notificationTask?.cancel()
        notificationTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await notificationService.scheduleCompletionNotification(for: session, from: now)
        }
    }

    private func message(for status: GWStatus) -> String? {
        switch status {
        case .notConfigured:
            return nil
        case .checking:
            return "출근 기록을 조회 중입니다."
        case .attendance:
            return nil
        case .requiresWebLogin(let message):
            return message
        case .readOnlySummary(let summary):
            return summary
        case .failed(let message):
            return message
        }
    }
}

private enum AgentUsagePaths {
    private static let home = FileManager.default.homeDirectoryForCurrentUser

    static let codexSessionsRoot = home
        .appendingPathComponent(".codex", isDirectory: true)
        .appendingPathComponent("sessions", isDirectory: true)

    static let claudeStatusLineBridgeURL = home
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("Application Support", isDirectory: true)
        .appendingPathComponent("Mac Work Timer", isDirectory: true)
        .appendingPathComponent("agent-usage", isDirectory: true)
        .appendingPathComponent("claude.json")

    static let claudeHudCacheURL = home
        .appendingPathComponent(".claude", isDirectory: true)
        .appendingPathComponent("plugins", isDirectory: true)
        .appendingPathComponent("claude-hud", isDirectory: true)
        .appendingPathComponent(".usage-cache.json")
}

enum DateFormatting {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    static func remaining(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    static func digital(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}
