import Foundation

public struct WeeklyWorkBalanceCalculator: Sendable {
    public static let dailyTargetDuration: TimeInterval = 8 * 60 * 60

    private let calendar: Calendar
    private let lunch: LunchBreak

    public init(timeZone: TimeZone = TimeZone(identifier: "Asia/Seoul")!) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        self.calendar = calendar
        self.lunch = LunchBreak(timeZone: timeZone)
    }

    public func weekStartString(containing date: Date) -> String {
        workDate(for: weekStart(containing: date))
    }

    public func creditedDuration(for records: [WeeklyAttendanceRecord]) -> TimeInterval {
        Dictionary(grouping: records, by: \.workDate).values.reduce(0) { total, dailyRecords in
            total + creditedDuration(forDayRecords: dailyRecords)
        }
    }

    public func summary(
        records: [WeeklyAttendanceRecord],
        todaySession: WorkSession,
        fetchedAt: Date,
        holidays: HolidayCalendar = HolidayCalendar()
    ) -> WeeklyWorkSummary? {
        guard let today = startOfWorkDate(todaySession.workDate) else {
            return nil
        }

        // GW may report the holiday itself, the user may have registered it, or both.
        let effectiveHolidays = HolidayCalendar(
            manualEntries: holidays.holidayDates.map { HolidayEntry(workDate: $0, title: holidays.title(for: $0) ?? HolidayEntry.defaultTitle) },
            records: records
        )
        let weekStartDate = weekStart(containing: today)
        let grouped = Dictionary(grouping: records, by: \.workDate)
        let allElapsedWeekdays = weekdays(from: weekStartDate, before: today)
        let holidayWorkDates = allElapsedWeekdays
            .map(workDate(for:))
            .filter(effectiveHolidays.isHoliday)
        let elapsedWeekdays = allElapsedWeekdays.filter { !effectiveHolidays.isHoliday(workDate(for: $0)) }
        var completedDuration: TimeInterval = 0
        var incompleteWorkDates: [String] = []

        for day in elapsedWeekdays {
            let dateText = workDate(for: day)
            guard let dailyRecords = grouped[dateText], !dailyRecords.isEmpty else {
                incompleteWorkDates.append(dateText)
                continue
            }

            if dailyRecords.contains(where: isIncompleteAttendance) {
                incompleteWorkDates.append(dateText)
            }
            completedDuration += creditedDuration(forDayRecords: dailyRecords)
        }

        if !effectiveHolidays.isHoliday(todaySession.workDate) {
            let todayCreditedLeave = grouped[todaySession.workDate, default: []].reduce(0) { total, record in
                guard record.kind == .creditedLeave else {
                    return total
                }
                return total + max(0, record.creditedDuration)
            }
            completedDuration += todayCreditedLeave
        }

        // Holiday work is overtime, not weekly flex: it must never shorten today's target.
        let overtimeDates = Set(holidayWorkDates).union(
            effectiveHolidays.isHoliday(todaySession.workDate) ? [todaySession.workDate] : []
        )
        let overtimeDuration = overtimeDates.reduce(0) { total, dateText in
            let dailyRecords = grouped[dateText, default: []].filter { $0.kind == .attendance }
            return total + creditedDuration(forDayRecords: dailyRecords)
        }

        let targetDuration = Double(elapsedWeekdays.count) * Self.dailyTargetDuration
        let balance = completedDuration - targetDuration
        let normalTargetAt = todaySession.targetAt
        let allFlexUsedTargetAt: Date
        if incompleteWorkDates.isEmpty {
            // Spend the surplus as work, not as wall-clock. Subtracting the balance from the
            // target directly would keep charging the lunch hour to a day that now finishes
            // before lunch even starts, making the readout up to an hour too late.
            let workLeftToday = max(0, todaySession.workdayMode.workDuration - balance)
            allFlexUsedTargetAt = max(
                lunch.endOfWork(startingAt: todaySession.workStartAt, creditedWork: workLeftToday),
                todaySession.workStartAt
            )
        } else {
            allFlexUsedTargetAt = normalTargetAt
        }

        return WeeklyWorkSummary(
            weekStart: workDate(for: weekStartDate),
            completedDuration: completedDuration,
            targetDurationThroughYesterday: targetDuration,
            balance: balance,
            normalTargetAt: normalTargetAt,
            allFlexUsedTargetAt: allFlexUsedTargetAt,
            fetchedAt: fetchedAt,
            incompleteWorkDates: incompleteWorkDates,
            holidayWorkDates: holidayWorkDates,
            overtimeDuration: overtimeDuration
        )
    }

    public func summary(
        cache: WeeklyAttendanceCache,
        todaySession: WorkSession,
        holidays: HolidayCalendar = HolidayCalendar()
    ) -> WeeklyWorkSummary? {
        guard cache.weekStart == weekStartString(containing: todaySession.workStartAt) else {
            return nil
        }
        return summary(
            records: cache.records,
            todaySession: todaySession,
            fetchedAt: cache.fetchedAt,
            holidays: holidays
        )
    }

    private func creditedDuration(forDayRecords records: [WeeklyAttendanceRecord]) -> TimeInterval {
        let creditedLeave = records.reduce(0) { total, record in
            total + max(0, record.creditedDuration)
        }
        let completedIntervals = records.compactMap { record -> DateInterval? in
            guard record.kind == .attendance,
                  let checkInAt = record.checkInAt,
                  let checkOutAt = record.checkOutAt,
                  checkOutAt >= checkInAt else {
                return nil
            }
            return DateInterval(start: checkInAt, end: checkOutAt)
        }
        let grossDuration = completedIntervals.reduce(0) { $0 + $1.duration }
        // A day gives up the break once, however many times it clocked in and out around it.
        let lunchOverlap = min(
            lunch.duration,
            completedIntervals.reduce(0) { $0 + lunch.overlap(with: $1) }
        )
        return creditedLeave + max(0, grossDuration - lunchOverlap)
    }

    private func isIncompleteAttendance(_ record: WeeklyAttendanceRecord) -> Bool {
        guard record.kind == .attendance else {
            return false
        }
        guard let checkInAt = record.checkInAt,
              let checkOutAt = record.checkOutAt else {
            return true
        }
        return checkOutAt < checkInAt
    }

    private func weekdays(from start: Date, before end: Date) -> [Date] {
        var days: [Date] = []
        var cursor = start
        while cursor < end {
            let weekday = calendar.component(.weekday, from: cursor)
            if weekday != 1 && weekday != 7 {
                days.append(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return days
    }

    private func weekStart(containing date: Date) -> Date {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: start) ?? start
    }

    private func startOfWorkDate(_ value: String) -> Date? {
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
