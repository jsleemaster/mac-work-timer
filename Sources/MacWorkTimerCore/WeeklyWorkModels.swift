import Foundation

public struct WeeklyAttendanceRecord: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case attendance
        case creditedLeave
        case explicitAbsence
        /// A company-wide non-working day. Unlike `creditedLeave` it carries no credit,
        /// because the day is removed from the weekly target instead of being paid into it.
        case holiday
    }

    public let workDate: String
    public let kind: Kind
    public let checkInAt: Date?
    public let checkOutAt: Date?
    public let creditedDuration: TimeInterval
    public let sourceText: String

    public init(
        workDate: String,
        kind: Kind,
        checkInAt: Date? = nil,
        checkOutAt: Date? = nil,
        creditedDuration: TimeInterval = 0,
        sourceText: String
    ) {
        self.workDate = workDate
        self.kind = kind
        self.checkInAt = checkInAt
        self.checkOutAt = checkOutAt
        self.creditedDuration = creditedDuration
        self.sourceText = sourceText
    }
}

public struct WeeklyAttendanceCache: Codable, Equatable, Sendable {
    public let weekStart: String
    public let fetchedAt: Date
    public let records: [WeeklyAttendanceRecord]

    public init(weekStart: String, fetchedAt: Date, records: [WeeklyAttendanceRecord]) {
        self.weekStart = weekStart
        self.fetchedAt = fetchedAt
        self.records = records
    }
}

public struct WeeklyWorkSummary: Equatable, Sendable {
    public let weekStart: String
    public let completedDuration: TimeInterval
    public let targetDurationThroughYesterday: TimeInterval
    public let balance: TimeInterval
    public let normalTargetAt: Date
    public let allFlexUsedTargetAt: Date
    public let fetchedAt: Date
    public let incompleteWorkDates: [String]
    /// Weekdays removed from the weekly target because they are holidays.
    public let holidayWorkDates: [String]
    /// Time worked on holidays. Deliberately kept out of `completedDuration` and `balance`
    /// so it is reported as overtime instead of shortening today's target.
    public let overtimeDuration: TimeInterval

    public init(
        weekStart: String,
        completedDuration: TimeInterval,
        targetDurationThroughYesterday: TimeInterval,
        balance: TimeInterval,
        normalTargetAt: Date,
        allFlexUsedTargetAt: Date,
        fetchedAt: Date,
        incompleteWorkDates: [String],
        holidayWorkDates: [String] = [],
        overtimeDuration: TimeInterval = 0
    ) {
        self.weekStart = weekStart
        self.completedDuration = completedDuration
        self.targetDurationThroughYesterday = targetDurationThroughYesterday
        self.balance = balance
        self.normalTargetAt = normalTargetAt
        self.allFlexUsedTargetAt = allFlexUsedTargetAt
        self.fetchedAt = fetchedAt
        self.incompleteWorkDates = incompleteWorkDates
        self.holidayWorkDates = holidayWorkDates
        self.overtimeDuration = overtimeDuration
    }

    public var isComplete: Bool {
        incompleteWorkDates.isEmpty
    }
}
