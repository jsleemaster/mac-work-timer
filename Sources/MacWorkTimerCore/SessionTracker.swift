import Foundation

public final class SessionTracker {
    private let clock: WorkdayClock
    private let store: StateStore

    public init(clock: WorkdayClock = WorkdayClock(), store: StateStore = .default) {
        self.clock = clock
        self.store = store
    }

    public func load() throws -> AppState {
        try store.load()
    }

    @discardableResult
    public func startOrResume(now: Date = Date()) throws -> AppState {
        var state = try store.load()
        state.todaySession = clock.session(for: now, existing: state.todaySession)
        try store.save(state)
        return state
    }

    @discardableResult
    public func updateGWStatus(_ status: GWStatus) throws -> AppState {
        var state = try store.load()
        state.gwStatus = status
        try store.save(state)
        return state
    }

    @discardableResult
    public func applyAttendance(_ record: AttendanceRecord) throws -> AppState {
        var state = try store.load()
        state.todaySession = record.session
        state.gwStatus = .attendance(record)
        try store.save(state)
        return state
    }

    @discardableResult
    public func clearSessionAndGWStatus() throws -> AppState {
        let state = AppState(todaySession: nil, gwStatus: .notConfigured, notificationSentForDate: nil)
        try store.save(state)
        return state
    }

    @discardableResult
    public func markNotificationSent(for workDate: String) throws -> AppState {
        var state = try store.load()
        state.notificationSentForDate = workDate
        try store.save(state)
        return state
    }

    @discardableResult
    public func completePetReveal(
        for workDate: String,
        availablePetIDs: [String],
        picker: ([String]) -> String? = { $0.randomElement() }
    ) throws -> AppState {
        var state = try store.load()
        state.completePetReveal(for: workDate, availablePetIDs: availablePetIDs, picker: picker)
        try store.save(state)
        return state
    }
}
