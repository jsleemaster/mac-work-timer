import Foundation

public struct WorkdayClock: Sendable {
    public let calendar: Calendar

    public init(timeZone: TimeZone = TimeZone(identifier: "Asia/Seoul")!) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    public func workDate(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    public func session(for now: Date, existing: WorkSession?) -> WorkSession? {
        guard !isWeekend(now) else {
            return nil
        }

        let today = workDate(for: now)
        if let existing, existing.workDate == today {
            return existing
        }

        return WorkSession(workDate: today, workStartAt: now)
    }

    public func remainingTime(for session: WorkSession, at now: Date) -> TimeInterval {
        max(0, session.targetAt.timeIntervalSince(now))
    }

    public func isComplete(_ session: WorkSession, at now: Date) -> Bool {
        remainingTime(for: session, at: now) == 0
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
}
