import Foundation

public enum AttendanceRecordParser {
    public static func parse(_ htmlOrText: String) -> AttendanceRecord? {
        let text = normalizedText(from: htmlOrText)
        let pattern = #"출근\s*(\d{4})\.(\d{2})\.(\d{2})\s+(\d{2}):(\d{2}):(\d{2})"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges == 7 else {
            return nil
        }

        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: text) else {
                return nil
            }
            return String(text[range])
        }

        guard
            let year = Int(group(1) ?? ""),
            let month = Int(group(2) ?? ""),
            let day = Int(group(3) ?? ""),
            let hour = Int(group(4) ?? ""),
            let minute = Int(group(5) ?? ""),
            let second = Int(group(6) ?? "")
        else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        guard let checkInAt = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ).date else {
            return nil
        }

        guard let sourceRange = Range(match.range(at: 0), in: text) else {
            return nil
        }

        return AttendanceRecord(
            workDate: String(format: "%04d-%02d-%02d", year, month, day),
            checkInAt: checkInAt,
            sourceText: String(text[sourceRange])
        )
    }

    private static func normalizedText(from htmlOrText: String) -> String {
        htmlOrText
            .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
