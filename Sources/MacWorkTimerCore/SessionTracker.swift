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
    public func startOrResume(now: Date = Date(), preferredStart: Date? = nil) throws -> AppState {
        var state = try store.load()
        let workDate = clock.workDate(for: now)
        let holidayDates = state.holidayCalendar.holidayDates
        state.todaySession = clock.session(
            for: preferredStart ?? now,
            existing: state.todaySession,
            holidayDates: holidayDates
        )
        if let preferredStart,
           clock.workDate(for: preferredStart) == workDate,
           let session = state.todaySession,
           session.workDate == workDate,
           shouldApplyPreferredStart(preferredStart, to: session, state: state, workDate: workDate) {
            state.todaySession = WorkSession(
                workDate: session.workDate,
                workStartAt: preferredStart,
                workdayMode: session.workdayMode
            )
            if state.notificationSentForDate == workDate {
                state.notificationSentForDate = nil
            }
        }
        try store.save(state)
        return state
    }

    private func shouldApplyPreferredStart(
        _ preferredStart: Date,
        to session: WorkSession,
        state: AppState,
        workDate: String
    ) -> Bool {
        guard preferredStart != session.workStartAt else {
            return false
        }

        if case .attendance(let record) = state.gwStatus, record.workDate == workDate {
            return false
        }

        return true
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
    public func updateWeeklyAttendanceCache(_ cache: WeeklyAttendanceCache) throws -> AppState {
        var state = try store.load()
        state.weeklyAttendanceCache = cache
        try store.save(state)
        return state
    }

    @discardableResult
    public func clearSessionAndGWStatus() throws -> AppState {
        // Manually registered holidays are user configuration, not GW state, so a logout keeps them.
        let holidays = (try? store.load().holidays) ?? []
        let state = AppState(
            todaySession: nil,
            gwStatus: .notConfigured,
            notificationSentForDate: nil,
            holidays: holidays
        )
        try store.save(state)
        return state
    }

    @discardableResult
    public func setWorkdayMode(_ mode: WorkdayMode, for workDate: String) throws -> AppState {
        var state = try store.load()
        state.workdayModeSelection = WorkdayModeSelection(workDate: workDate, mode: mode)
        if let session = state.todaySession, session.workDate == workDate {
            state.todaySession = session.withWorkdayMode(mode)
        }
        if state.notificationSentForDate == workDate {
            state.notificationSentForDate = nil
        }
        try store.save(state)
        return state
    }

    /// Registers or clears a manual holiday. Marking today a holiday also drops the running
    /// session and the sent-notification marker, so the app goes as quiet as it does on a weekend.
    @discardableResult
    public func setHoliday(_ isHoliday: Bool, for workDate: String, title: String?) throws -> AppState {
        var state = try store.load()
        var holidays = state.holidays.filter { $0.workDate != workDate }

        if isHoliday {
            holidays.append(HolidayEntry(workDate: workDate, title: title ?? HolidayEntry.defaultTitle))
            if state.todaySession?.workDate == workDate {
                state.todaySession = nil
            }
            if state.notificationSentForDate == workDate {
                state.notificationSentForDate = nil
            }
        }

        state.holidays = holidays.sorted { $0.workDate < $1.workDate }
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
