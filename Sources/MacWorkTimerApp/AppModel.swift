import AppKit
import Foundation
import MacWorkTimerCore
import SwiftUI

@MainActor
final class AppModel: NSObject, ObservableObject {
    static let shared = AppModel()

    @Published private(set) var now = Date()
    @Published var state: AppState = .empty
    @Published var userID = ""
    @Published var password = ""
    @Published var statusMessage: String?
    @Published var launchAtLogin = false
    @Published var isLoggingIn = false

    private let clock: WorkdayClock
    private let tracker: SessionTracker
    private let credentialStore: KeychainCredentialStore
    private let gwClient: GWClient
    private let notificationService: NotificationService
    private let loginItemsController: LoginItemsController
    private var timer: Timer?
    private var notificationObservers: [NSObjectProtocol] = []
    private var didLoadStoredCredentials = false
    private var isLoadingStoredCredentials = false

    override init() {
        let clock = WorkdayClock()
        let tracker = SessionTracker(clock: clock)
        let credentialStore = KeychainCredentialStore()

        self.clock = clock
        self.tracker = tracker
        self.credentialStore = credentialStore
        self.gwClient = GWClient(credentialStore: credentialStore)
        self.notificationService = NotificationService()
        self.loginItemsController = LoginItemsController()
        self.launchAtLogin = loginItemsController.isEnabled

        super.init()

        loadStoredState()
        startClock()
        observeSystemActivity()

        Task {
            _ = await notificationService.requestAuthorization()
            if currentSession == nil {
                loadStoredCredentialsInBackground(refreshAfterLoad: true)
            }
            await scheduleOrDeliverNotificationIfNeeded()
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
        guard let elapsed else {
            return 0
        }
        return min(1, max(0, elapsed / WorkSession.workdayDuration))
    }

    var menuBarTitle: String {
        guard let remaining else {
            return "Work Timer"
        }
        return MenuBarStatusFormatter.title(remaining: remaining)
    }

    func loadStoredState() {
        do {
            state = try tracker.load()
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func login() {
        do {
            let trimmedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
            try credentialStore.saveCredentials(GWCredentials(userID: trimmedUserID, password: password))
            userID = trimmedUserID
            refreshAttendance()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func refreshAttendance() {
        if currentCredentials == nil && !didLoadStoredCredentials {
            loadStoredCredentialsInBackground(refreshAfterLoad: true)
            statusMessage = currentSession == nil ? "저장된 GW 계정을 읽는 중입니다." : nil
            return
        }

        guard let credentials = currentCredentials else {
            statusMessage = "GW 계정으로 먼저 로그인하세요."
            return
        }

        let hasStoredSession = currentSession != nil
        state.gwStatus = .checking
        isLoggingIn = true

        Task {
            let status = await gwClient.refreshTodayStatus(credentials: credentials)
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
            isLoggingIn = false
            await scheduleOrDeliverNotificationIfNeeded()
        }
    }

    func applyAttendanceText(_ text: String) {
        guard let record = AttendanceRecordParser.parse(text) else {
            statusMessage = "로그인 후 출근 기록을 찾지 못했습니다."
            return
        }

        do {
            state = try tracker.applyAttendance(record)
            statusMessage = nil
            Task {
                await scheduleOrDeliverNotificationIfNeeded()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func logout() {
        do {
            try credentialStore.deleteCredentials()
            userID = ""
            password = ""
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

    private func loadCredentialsForEditing() {
        guard let credentials = try? credentialStore.loadCredentials() else {
            return
        }
        userID = credentials.userID
        password = credentials.password
    }

    private func loadStoredCredentialsInBackground(refreshAfterLoad: Bool) {
        guard !isLoadingStoredCredentials else {
            return
        }

        isLoadingStoredCredentials = true
        let store = credentialStore

        Task { [weak self, store] in
            let result = await Task.detached {
                Result {
                    try store.loadCredentials()
                }
            }.value

            guard let self else {
                return
            }

            isLoadingStoredCredentials = false
            didLoadStoredCredentials = true

            switch result {
            case .success(let credentials):
                guard let credentials else {
                    if currentSession == nil {
                        statusMessage = "GW 계정으로 먼저 로그인하세요."
                    }
                    return
                }

                userID = credentials.userID
                password = credentials.password
                if refreshAfterLoad {
                    refreshAttendance()
                }
            case .failure(let error):
                if currentSession == nil {
                    statusMessage = error.localizedDescription
                }
            }
        }
    }

    private var currentCredentials: GWCredentials? {
        let trimmedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserID.isEmpty, !password.isEmpty else {
            return nil
        }

        return GWCredentials(userID: trimmedUserID, password: password)
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
        Task {
            await scheduleOrDeliverNotificationIfNeeded()
        }
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
                }
            }
        )
    }

    private func scheduleOrDeliverNotificationIfNeeded() async {
        guard let session = currentSession else {
            return
        }

        if clock.isComplete(session, at: now) {
            guard state.notificationSentForDate != session.workDate else {
                return
            }

            await notificationService.deliverCompletionNotification(for: session)
            do {
                state = try tracker.markNotificationSent(for: session.workDate)
            } catch {
                statusMessage = error.localizedDescription
            }
        } else {
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
