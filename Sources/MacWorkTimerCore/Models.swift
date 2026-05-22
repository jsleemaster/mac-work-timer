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

    public init(todaySession: WorkSession?, gwStatus: GWStatus, notificationSentForDate: String?) {
        self.todaySession = todaySession
        self.gwStatus = gwStatus
        self.notificationSentForDate = notificationSentForDate
    }

    public static let empty = AppState(
        todaySession: nil,
        gwStatus: .notConfigured,
        notificationSentForDate: nil
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

public struct GWCredentials: Codable, Equatable, Sendable {
    public let userID: String
    public let password: String

    public init(userID: String, password: String) {
        self.userID = userID
        self.password = password
    }
}
