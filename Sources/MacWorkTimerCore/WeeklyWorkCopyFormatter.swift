import Foundation

public struct WeeklyBalanceCopy: Equatable, Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public enum WeeklyWorkCopyFormatter {
    public static let loginRecoveryPrompt = "주간 기록 연결하기"

    public static func balanceLine(_ balance: TimeInterval) -> String {
        let copy = balanceCopy(balance)
        return "\(copy.label) \(copy.value)"
    }

    public static func balanceCopy(_ balance: TimeInterval) -> WeeklyBalanceCopy {
        let totalMinutes = Int(abs(balance) / 60)
        guard totalMinutes > 0 else {
            return WeeklyBalanceCopy(label: "이번 주", value: "딱 맞아요")
        }
        let value = durationText(totalMinutes: totalMinutes)
        if balance > 0 {
            return WeeklyBalanceCopy(label: "이번 주 여유", value: "+\(value)")
        }
        return WeeklyBalanceCopy(label: "이번 주 부족", value: value)
    }

    /// Holiday work is reported on its own line so it never reads as flex time to spend.
    public static func overtimeCopy(_ overtime: TimeInterval) -> WeeklyBalanceCopy? {
        let totalMinutes = Int(max(0, overtime) / 60)
        guard totalMinutes > 0 else {
            return nil
        }
        return WeeklyBalanceCopy(label: "이번 주 초과근무", value: "+\(durationText(totalMinutes: totalMinutes))")
    }

    public static func overtimeLine(_ overtime: TimeInterval) -> String? {
        guard let copy = overtimeCopy(overtime) else {
            return nil
        }
        return "\(copy.label) \(copy.value)"
    }

    public static func holidayLine(_ holidayWorkDates: [String]) -> String? {
        guard !holidayWorkDates.isEmpty else {
            return nil
        }
        return "휴일 \(holidayWorkDates.count)일 제외"
    }

    private static func durationText(totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return "\(minutes)분"
        }
        if minutes == 0 {
            return "\(hours)시간"
        }
        return "\(hours)시간 \(minutes)분"
    }
}
