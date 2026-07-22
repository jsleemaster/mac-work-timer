import Foundation

public enum WeeklyWorkCopyFormatter {
    public static func balanceLine(_ balance: TimeInterval) -> String {
        let totalMinutes = Int(abs(balance) / 60)
        guard totalMinutes > 0 else {
            return "이번 주 딱 맞아요"
        }

        let value = durationText(totalMinutes: totalMinutes)
        if balance > 0 {
            return "이번 주 여유 +\(value)"
        }
        return "이번 주 부족 \(value)"
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
