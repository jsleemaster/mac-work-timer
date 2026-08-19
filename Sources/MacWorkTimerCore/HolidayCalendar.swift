import Foundation

/// A day the company does not expect work: a public holiday, a substitute holiday,
/// or a company-wide closure. Distinct from credited leave, which is personal time
/// off that still counts toward the 40-hour week.
public struct HolidayEntry: Codable, Equatable, Hashable, Sendable {
    public static let defaultTitle = "휴일"

    public let workDate: String
    public let title: String

    public init(workDate: String, title: String = HolidayEntry.defaultTitle) {
        self.workDate = workDate
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = trimmed.isEmpty ? HolidayEntry.defaultTitle : trimmed
    }
}

/// Resolves whether a work date is a holiday by merging the two sources the app trusts:
/// the dates the user registered by hand, and the `.holiday` rows GW reported for the
/// cached week. Manual entries win on the title so a personal label is never overwritten.
public struct HolidayCalendar: Equatable, Sendable {
    private let manualTitles: [String: String]
    private let recordDates: Set<String>

    public init(manualEntries: [HolidayEntry] = [], records: [WeeklyAttendanceRecord] = []) {
        self.manualTitles = Dictionary(
            manualEntries.map { ($0.workDate, $0.title) },
            uniquingKeysWith: { _, latest in latest }
        )
        self.recordDates = Set(records.filter { $0.kind == .holiday }.map(\.workDate))
    }

    public var holidayDates: Set<String> {
        Set(manualTitles.keys).union(recordDates)
    }

    public var isEmpty: Bool {
        manualTitles.isEmpty && recordDates.isEmpty
    }

    public func isHoliday(_ workDate: String) -> Bool {
        manualTitles[workDate] != nil || recordDates.contains(workDate)
    }

    /// Only manual entries can be toggled off, so the UI needs to tell the two apart.
    public func isManualHoliday(_ workDate: String) -> Bool {
        manualTitles[workDate] != nil
    }

    public func title(for workDate: String) -> String? {
        if let title = manualTitles[workDate] {
            return title
        }
        return recordDates.contains(workDate) ? HolidayEntry.defaultTitle : nil
    }
}
