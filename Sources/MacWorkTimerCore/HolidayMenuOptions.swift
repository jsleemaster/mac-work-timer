import Foundation

/// One selectable day in the holiday menu, carrying everything the menu needs to draw it:
/// the label, whether the day is already a holiday, and whether the user may change it.
/// GW-reported holidays are locked because the next attendance refresh would restore them.
public struct HolidayMenuOption: Equatable, Sendable {
    public let workDate: String
    public let label: String
    public let title: String?
    public let isHoliday: Bool
    public let isLocked: Bool
    public let isToday: Bool
    public let isPast: Bool

    public init(
        workDate: String,
        label: String,
        title: String?,
        isHoliday: Bool,
        isLocked: Bool,
        isToday: Bool,
        isPast: Bool
    ) {
        self.workDate = workDate
        self.label = label
        self.title = title
        self.isHoliday = isHoliday
        self.isLocked = isLocked
        self.isToday = isToday
        self.isPast = isPast
    }
}

/// Builds the Monday-Friday list the status bar menu offers, so a holiday can be registered
/// for a day that has already passed and not only for today. The current week is the useful
/// span because that is exactly what the 40-hour weekly balance is computed over; anything
/// outside it is registered from the settings window instead.
public struct HolidayMenuOptionsBuilder: Sendable {
    private static let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private static let weekdaysPerWeek = 5

    private let calendar: Calendar

    public init(timeZone: TimeZone = TimeZone(identifier: "Asia/Seoul")!) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        self.calendar = calendar
    }

    public func currentWeekOptions(today: String, holidays: HolidayCalendar) -> [HolidayMenuOption] {
        guard let todayDate = date(from: today) else {
            return []
        }

        let weekStartDate = weekStart(containing: todayDate)
        return (0..<Self.weekdaysPerWeek).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStartDate) else {
                return nil
            }
            return option(for: day, today: today, holidays: holidays)
        }
    }

    private func option(for day: Date, today: String, holidays: HolidayCalendar) -> HolidayMenuOption {
        let dateText = workDate(for: day)
        let isHoliday = holidays.isHoliday(dateText)
        let isLocked = isHoliday && !holidays.isManualHoliday(dateText)
        let title = holidays.title(for: dateText)
        let isToday = dateText == today

        var label = shortLabel(for: day)
        if isToday {
            label += " · 오늘"
        }
        if let title {
            label += isLocked ? " · \(title) (GW)" : " · \(title)"
        }

        return HolidayMenuOption(
            workDate: dateText,
            label: label,
            title: title,
            isHoliday: isHoliday,
            isLocked: isLocked,
            isToday: isToday,
            isPast: dateText < today
        )
    }

    private func shortLabel(for day: Date) -> String {
        let components = calendar.dateComponents([.month, .day, .weekday], from: day)
        let weekdaySymbol = Self.weekdaySymbols[max(0, min(6, (components.weekday ?? 1) - 1))]
        return "\(components.month ?? 0)/\(components.day ?? 0) (\(weekdaySymbol))"
    }

    private func weekStart(containing date: Date) -> Date {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: start) ?? start
    }

    private func date(from value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            return nil
        }
        return DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: parts[0],
            month: parts[1],
            day: parts[2]
        ).date
    }

    private func workDate(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
