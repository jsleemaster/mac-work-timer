import Foundation

public struct WeeklyAttendanceParser: Sendable {
    private let calendar: Calendar

    public init(timeZone: TimeZone = TimeZone(identifier: "Asia/Seoul")!) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    public func parse(_ htmlOrText: String) -> [WeeklyAttendanceRecord] {
        var seenRows = Set<String>()
        return normalizedRows(from: htmlOrText).compactMap { row in
            guard seenRows.insert(row).inserted else {
                return nil
            }
            return parseRow(row)
        }
    }

    private func parseRow(_ row: String) -> WeeklyAttendanceRecord? {
        guard let workDate = firstMatch(in: row, pattern: #"^\s*(\d{4}-\d{2}-\d{2})\b"#) else {
            return nil
        }

        let timeLikeTokens = matches(in: row, pattern: #"(?<!\d)\d{2}:\d{2}(?!\d)"#)
        let validTimeTokens = matches(in: row, pattern: #"(?<!\d)(?:[01]\d|2[0-3]):[0-5]\d(?!\d)"#)
        guard timeLikeTokens.count == validTimeTokens.count else {
            return nil
        }

        if row.contains("오전반차") || row.contains("오후반차") {
            return WeeklyAttendanceRecord(
                workDate: workDate,
                kind: .creditedLeave,
                creditedDuration: 4 * 60 * 60,
                sourceText: row
            )
        }

        if row.contains("연차") || row.contains("휴가") || row.contains("공휴일") {
            return WeeklyAttendanceRecord(
                workDate: workDate,
                kind: .creditedLeave,
                creditedDuration: 8 * 60 * 60,
                sourceText: row
            )
        }

        if row.contains("결근") {
            return WeeklyAttendanceRecord(
                workDate: workDate,
                kind: .explicitAbsence,
                sourceText: row
            )
        }

        guard let checkInTime = validTimeTokens.first,
              let checkInAt = date(workDate: workDate, time: checkInTime) else {
            return nil
        }

        let checkOutAt = validTimeTokens.dropFirst().first.flatMap {
            date(workDate: workDate, time: $0)
        }

        return WeeklyAttendanceRecord(
            workDate: workDate,
            kind: .attendance,
            checkInAt: checkInAt,
            checkOutAt: checkOutAt,
            sourceText: row
        )
    }

    private func normalizedRows(from htmlOrText: String) -> [String] {
        let withRowBoundaries = htmlOrText
            .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"</(?:td|th)>"#, with: "\t", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"</tr>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = withRowBoundaries
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .replacingOccurrences(of: #"[ \u{00A0}]+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        var rows: [String] = []
        var currentCells: [String] = []
        for line in lines {
            if hasMatch(in: line, pattern: #"^\s*\d{4}-\d{2}-\d{2}\b"#) {
                if !currentCells.isEmpty {
                    rows.append(currentCells.joined(separator: "\t"))
                }
                currentCells = [line]
            } else if !currentCells.isEmpty {
                currentCells.append(line)
            }
        }
        if !currentCells.isEmpty {
            rows.append(currentCells.joined(separator: "\t"))
        }
        return rows
    }

    private func date(workDate: String, time: String) -> Date? {
        let parts = (workDate + "-" + time.replacingOccurrences(of: ":", with: "-"))
            .split(separator: "-")
            .compactMap { Int($0) }
        guard parts.count == 5 else {
            return nil
        }

        return DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: parts[0],
            month: parts[1],
            day: parts[2],
            hour: parts[3],
            minute: parts[4]
        ).date
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..<text.endIndex, in: text)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func hasMatch(in text: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        return regex.firstMatch(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        ) != nil
    }

    private func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range(at: 0), in: text) else {
                return nil
            }
            return String(text[range])
        }
    }
}
