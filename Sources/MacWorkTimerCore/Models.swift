import Foundation

public enum WorkdayMode: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case fullDay
    case morningHalfDay
    case afternoonHalfDay

    /// Work the day owes, lunch excluded. The wall-clock span is longer whenever the shift
    /// actually runs through the lunch window, which `LunchBreak` decides per session rather
    /// than assuming.
    public var workDuration: TimeInterval {
        switch self {
        case .fullDay:
            return 8 * 60 * 60
        case .morningHalfDay, .afternoonHalfDay:
            return 4 * 60 * 60
        }
    }

    public var title: String {
        switch self {
        case .fullDay:
            return "종일"
        case .morningHalfDay:
            return "오전 반차"
        case .afternoonHalfDay:
            return "오후 반차"
        }
    }
}

public struct WorkdayModeSelection: Codable, Equatable, Sendable {
    public let workDate: String
    public let mode: WorkdayMode

    public init(workDate: String, mode: WorkdayMode) {
        self.workDate = workDate
        self.mode = mode
    }
}

public struct WorkSession: Codable, Equatable, Sendable {
    /// Fallback span for readouts with no session yet: a full day plus the lunch it spans.
    public static let workdayDuration: TimeInterval = WorkdayMode.fullDay.workDuration + LunchBreak.standard.duration

    public let workDate: String
    public let workStartAt: Date
    public let workdayMode: WorkdayMode

    public init(workDate: String, workStartAt: Date, workdayMode: WorkdayMode = .fullDay) {
        self.workDate = workDate
        self.workStartAt = workStartAt
        self.workdayMode = workdayMode
    }

    private enum CodingKeys: String, CodingKey {
        case workDate
        case workStartAt
        case workdayMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.workDate = try container.decode(String.self, forKey: .workDate)
        self.workStartAt = try container.decode(Date.self, forKey: .workStartAt)
        self.workdayMode = try container.decodeIfPresent(WorkdayMode.self, forKey: .workdayMode) ?? .fullDay
    }

    public var targetAt: Date {
        LunchBreak.standard.endOfWork(startingAt: workStartAt, creditedWork: workdayMode.workDuration)
    }

    /// Wall-clock length of the day, derived from the target rather than assumed, so progress
    /// readouts and the pet stay in step with the time the timer is actually counting down to.
    public var workdayDuration: TimeInterval {
        targetAt.timeIntervalSince(workStartAt)
    }

    public var isWeekend: Bool {
        false
    }

    public func withWorkdayMode(_ workdayMode: WorkdayMode) -> WorkSession {
        WorkSession(workDate: workDate, workStartAt: workStartAt, workdayMode: workdayMode)
    }
}

public enum GWStatus: Codable, Equatable, Sendable {
    case notConfigured
    case checking
    case attendance(AttendanceRecord)
    case requiresWebLogin(String)
    case readOnlySummary(String)
    case failed(String)
}

public struct AttendanceRecord: Codable, Equatable, Sendable {
    public let workDate: String
    public let checkInAt: Date
    public let sourceText: String

    public init(workDate: String, checkInAt: Date, sourceText: String) {
        self.workDate = workDate
        self.checkInAt = checkInAt
        self.sourceText = sourceText
    }

    public var session: WorkSession {
        WorkSession(workDate: workDate, workStartAt: checkInAt)
    }
}

public struct AppState: Codable, Equatable, Sendable {
    public var todaySession: WorkSession?
    public var gwStatus: GWStatus
    public var notificationSentForDate: String?
    public var petReveal: PetRevealState?
    public var workdayModeSelection: WorkdayModeSelection?
    public var weeklyAttendanceCache: WeeklyAttendanceCache?
    /// Holidays the user registered by hand. GW-reported holidays are not stored here;
    /// they are derived from `weeklyAttendanceCache` so a refresh always wins.
    public var holidays: [HolidayEntry]

    public init(
        todaySession: WorkSession?,
        gwStatus: GWStatus,
        notificationSentForDate: String?,
        petReveal: PetRevealState? = nil,
        workdayModeSelection: WorkdayModeSelection? = nil,
        weeklyAttendanceCache: WeeklyAttendanceCache? = nil,
        holidays: [HolidayEntry] = []
    ) {
        self.todaySession = todaySession
        self.gwStatus = gwStatus
        self.notificationSentForDate = notificationSentForDate
        self.petReveal = petReveal
        self.workdayModeSelection = workdayModeSelection
        self.weeklyAttendanceCache = weeklyAttendanceCache
        self.holidays = holidays
    }

    private enum CodingKeys: String, CodingKey {
        case todaySession
        case gwStatus
        case notificationSentForDate
        case petReveal
        case workdayModeSelection
        case weeklyAttendanceCache
        case holidays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.todaySession = try container.decodeIfPresent(WorkSession.self, forKey: .todaySession)
        self.gwStatus = try container.decode(GWStatus.self, forKey: .gwStatus)
        self.notificationSentForDate = try container.decodeIfPresent(String.self, forKey: .notificationSentForDate)
        self.petReveal = try container.decodeIfPresent(PetRevealState.self, forKey: .petReveal)
        self.workdayModeSelection = try container.decodeIfPresent(WorkdayModeSelection.self, forKey: .workdayModeSelection)
        self.weeklyAttendanceCache = try container.decodeIfPresent(WeeklyAttendanceCache.self, forKey: .weeklyAttendanceCache)
        self.holidays = try container.decodeIfPresent([HolidayEntry].self, forKey: .holidays) ?? []
    }

    /// Manual entries merged with whatever holidays the cached GW week reported.
    public var holidayCalendar: HolidayCalendar {
        HolidayCalendar(manualEntries: holidays, records: weeklyAttendanceCache?.records ?? [])
    }

    public func isHoliday(on date: Date = Date(), clock: WorkdayClock = WorkdayClock()) -> Bool {
        holidayCalendar.isHoliday(clock.workDate(for: date))
    }

    public static let empty = AppState(
        todaySession: nil,
        gwStatus: .notConfigured,
        notificationSentForDate: nil,
        petReveal: nil,
        workdayModeSelection: nil,
        weeklyAttendanceCache: nil
    )

    public func currentSession(on date: Date = Date(), clock: WorkdayClock = WorkdayClock()) -> WorkSession? {
        let today = clock.workDate(for: date)
        let mode = workdayMode(for: today)

        // Holidays behave like weekends: no session, so no timer, pet, or leave alert.
        guard !holidayCalendar.isHoliday(today) else {
            return nil
        }

        if case .attendance(let record) = gwStatus, record.workDate == today {
            return record.session.withWorkdayMode(mode)
        }

        guard let todaySession, todaySession.workDate == today else {
            return nil
        }

        return todaySession.withWorkdayMode(mode)
    }

    public func workdayMode(on date: Date = Date(), clock: WorkdayClock = WorkdayClock()) -> WorkdayMode {
        workdayMode(for: clock.workDate(for: date))
    }

    public func workdayMode(for workDate: String) -> WorkdayMode {
        guard workdayModeSelection?.workDate == workDate else {
            return .fullDay
        }

        return workdayModeSelection?.mode ?? .fullDay
    }
}

public struct PetRevealState: Codable, Equatable, Sendable {
    public static let defaultPetID = "default"

    public let workDate: String
    public let isRevealed: Bool
    public let selectedPetID: String

    public init(workDate: String, isRevealed: Bool, selectedPetID: String) {
        self.workDate = workDate
        self.isRevealed = isRevealed
        self.selectedPetID = selectedPetID
    }
}

public enum PetRevealDisplay: Equatable, Sendable {
    case idle
    case capsuleIdle
    case petVisible(String)
}

public extension AppState {
    func petRevealDisplay(
        on date: Date = Date(),
        clock: WorkdayClock = WorkdayClock(),
        availablePetIDs: [String]
    ) -> PetRevealDisplay {
        guard let session = currentSession(on: date, clock: clock) else {
            return .idle
        }

        guard let petReveal,
              petReveal.workDate == session.workDate,
              petReveal.isRevealed else {
            return .capsuleIdle
        }

        return .petVisible(resolvedPetID(petReveal.selectedPetID, availablePetIDs: availablePetIDs))
    }

    mutating func completePetReveal(
        for workDate: String,
        availablePetIDs: [String],
        picker: ([String]) -> String? = { $0.randomElement() }
    ) {
        let selectedPetID = selectPetID(from: availablePetIDs, picker: picker)
        petReveal = PetRevealState(workDate: workDate, isRevealed: true, selectedPetID: selectedPetID)
    }

    private func selectPetID(from availablePetIDs: [String], picker: ([String]) -> String?) -> String {
        let candidates = petCandidates(from: availablePetIDs)

        if candidates.count == 1, let onlyPetID = candidates.first {
            return onlyPetID
        }

        if let selectedPetID = picker(candidates), candidates.contains(selectedPetID) {
            return selectedPetID
        }

        return candidates.randomElement() ?? PetRevealState.defaultPetID
    }

    private func resolvedPetID(_ petID: String, availablePetIDs: [String]) -> String {
        let candidates = petCandidates(from: availablePetIDs)
        return candidates.contains(petID) ? petID : PetRevealState.defaultPetID
    }

    private func petCandidates(from availablePetIDs: [String]) -> [String] {
        [PetRevealState.defaultPetID] + availablePetIDs.filter { $0 != PetRevealState.defaultPetID }
    }
}

public struct GWCredentials: Codable, Equatable, Sendable {
    public let userID: String
    public let password: String

    public init(userID: String, password: String) {
        self.userID = userID
        self.password = password
    }
}
