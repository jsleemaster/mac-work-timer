import Foundation

public enum MenuBarStatusFormatter {
    public static func title(remaining: TimeInterval) -> String {
        let seconds = max(0, Int(remaining.rounded()))

        if seconds == 0 {
            return "퇴근"
        }

        if seconds < 60 {
            return "\(seconds)s"
        }

        if seconds < 3600 {
            return "\(seconds / 60)m"
        }

        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }

    public static func urgency(progress: Double) -> Double {
        min(1, max(0, progress))
    }
}
