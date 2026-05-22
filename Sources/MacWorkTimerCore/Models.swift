import Foundation

public struct WorkSession: Codable, Equatable, Sendable {
    public static let workdayDuration: TimeInterval = 9 * 60 * 60

    public let workDate: String
    public let workStartAt: Date

    public init(workDate: String, workStartAt: Date) {
        self.workDate = workDate
        self.workStartAt = workStartAt
    }

    public var targetAt: Date {
        workStartAt.addingTimeInterval(Self.workdayDuration)
    }

    public var isWeekend: Bool {
        false
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

    public init(
        todaySession: WorkSession?,
        gwStatus: GWStatus,
        notificationSentForDate: String?,
        petReveal: PetRevealState? = nil
    ) {
        self.todaySession = todaySession
        self.gwStatus = gwStatus
        self.notificationSentForDate = notificationSentForDate
        self.petReveal = petReveal
    }

    public static let empty = AppState(
        todaySession: nil,
        gwStatus: .notConfigured,
        notificationSentForDate: nil,
        petReveal: nil
    )

    public func currentSession(on date: Date = Date(), clock: WorkdayClock = WorkdayClock()) -> WorkSession? {
        let today = clock.workDate(for: date)

        if case .attendance(let record) = gwStatus, record.workDate == today {
            return record.session
        }

        guard let todaySession, todaySession.workDate == today else {
            return nil
        }

        return todaySession
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
        guard !availablePetIDs.isEmpty else {
            return PetRevealState.defaultPetID
        }

        if availablePetIDs.count == 1, let onlyPetID = availablePetIDs.first {
            return onlyPetID
        }

        if let selectedPetID = picker(availablePetIDs), availablePetIDs.contains(selectedPetID) {
            return selectedPetID
        }

        return availablePetIDs.randomElement() ?? PetRevealState.defaultPetID
    }

    private func resolvedPetID(_ petID: String, availablePetIDs: [String]) -> String {
        guard !availablePetIDs.isEmpty else {
            return PetRevealState.defaultPetID
        }

        return availablePetIDs.contains(petID) ? petID : (availablePetIDs.first ?? PetRevealState.defaultPetID)
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
