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
        applyWeeklyCheckIn(to: &state, today: workDate)
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

        if weeklyCheckIn(for: workDate, in: state.weeklyAttendanceCache) != nil {
            return false
        }

        return true
    }

    /// Earliest GW check-in the weekly list holds for the date. A day can carry several rows.
    private func weeklyCheckIn(for workDate: String, in cache: WeeklyAttendanceCache?) -> Date? {
        cache?.records
            .filter { $0.workDate == workDate && $0.kind == .attendance }
            .compactMap(\.checkInAt)
            .min()
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
    public func updateWeeklyAttendanceCache(_ cache: WeeklyAttendanceCache, now: Date = Date()) throws -> AppState {
        var state = try store.load()
        state.weeklyAttendanceCache = cache
        applyWeeklyCheckIn(to: &state, today: clock.workDate(for: now))
        try store.save(state)
        return state
    }

    /// The today-status lookup is often blocked by second-factor login while the weekly list
    /// still loads, which would leave today's timer on the local activity guess. When the weekly
    /// list carries today's GW check-in, it replaces that guess — but never a today-status record.
    /// `gwStatus` is left alone so the UI keeps saying the web login still needs attention.
    private func applyWeeklyCheckIn(to state: inout AppState, today: String) {
        guard let session = state.todaySession, session.workDate == today else {
            return
        }
        if case .attendance(let record) = state.gwStatus, record.workDate == today {
            return
        }
        guard let checkInAt = weeklyCheckIn(for: today, in: state.weeklyAttendanceCache),
              checkInAt != session.workStartAt else {
            return
        }

        state.todaySession = WorkSession(workDate: today, workStartAt: checkInAt, workdayMode: session.workdayMode)
        if state.notificationSentForDate == today {
            state.notificationSentForDate = nil
        }
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
