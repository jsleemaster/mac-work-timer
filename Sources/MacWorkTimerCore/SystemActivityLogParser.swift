import Foundation

public enum SystemActivityLogParser {
    public static func firstUserActivity(in log: String, workDate: String) -> Date? {
        var earliest: Date?

        for line in log.split(separator: "\n", omittingEmptySubsequences: true) {
            guard line.hasPrefix(workDate),
                  isUserActivityLine(line),
                  let date = date(from: String(line.prefix(25))) else {
                continue
            }

            if earliest == nil || date < earliest! {
                earliest = date
            }
        }

        return earliest
    }

    private static func isUserActivityLine(_ line: Substring) -> Bool {
        isFreshUserActivity(line)
            && !line.contains("SRPrevSleep")
            && (line.contains("WindowServer") || line.contains("loginwindow") || line.contains("Loginwindow User Activity"))
    }

    private static func isFreshUserActivity(_ line: Substring) -> Bool {
        line.contains(" Created UserIsActive ") || line.contains(" TurnedOn UserIsActive ")
    }

    private static func date(from text: String) -> Date? {
        formatter.date(from: text)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()
}
