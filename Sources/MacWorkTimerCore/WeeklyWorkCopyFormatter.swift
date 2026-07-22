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
