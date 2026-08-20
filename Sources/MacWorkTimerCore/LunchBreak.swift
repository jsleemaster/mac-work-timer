import Foundation

/// The unpaid lunch window, and the single place that decides how it bends a workday.
///
/// Two questions have to agree with each other: "how much work does this span credit?" and
/// "when does the day end if it owes this much work?". Answering the second by adding a fixed
/// lunch hour to the start time silently assumes the day spans noon. It usually does — but a
/// shift that ends before noon never reaches lunch, and one that starts after lunch has already
/// missed it, and in both cases the fixed hour makes the target an hour too late. So the end time
/// is solved from the credited amount instead, which keeps `endOfWork` the exact inverse of
/// `creditedDuration`.
public struct LunchBreak: Equatable, Sendable {
    public static let standard = LunchBreak()

    private let startHour: Int
    private let endHour: Int
    private let calendar: Calendar

    public init(
        startHour: Int = 12,
        endHour: Int = 13,
        timeZone: TimeZone = TimeZone(identifier: "Asia/Seoul")!
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.startHour = startHour
        self.endHour = endHour
    }

    /// How long the break lasts, which is also the most a single day can ever deduct.
    public var duration: TimeInterval {
        TimeInterval((endHour - startHour) * 60 * 60)
    }

    public func overlap(with interval: DateInterval) -> TimeInterval {
        guard let window = window(containing: interval.start) else {
            return 0
        }
        let start = max(interval.start, window.start)
        let end = min(interval.end, window.end)
        return max(0, end.timeIntervalSince(start))
    }

    /// Work credited for a span, with any lunch it covers removed.
    public func creditedDuration(from start: Date, to end: Date) -> TimeInterval {
        guard end > start else {
            return 0
        }
        let gross = end.timeIntervalSince(start)
        return max(0, gross - overlap(with: DateInterval(start: start, end: end)))
    }

    /// When a day that starts at `startingAt` and owes `creditedWork` of work ends.
    ///
    /// Lunch is stepped over only if the work actually runs into it: work that finishes before
    /// the window, or starts after it, is charged nothing.
    public func endOfWork(startingAt start: Date, creditedWork: TimeInterval) -> Date {
        guard creditedWork > 0 else {
            return start
        }
        guard let window = window(containing: start), start < window.end else {
            return start.addingTimeInterval(creditedWork)
        }

        // Work available before the break; a start inside the break has none.
        let beforeBreak = max(0, window.start.timeIntervalSince(start))
        if creditedWork <= beforeBreak {
            return start.addingTimeInterval(creditedWork)
        }
        return window.end.addingTimeInterval(creditedWork - beforeBreak)
    }

    private func window(containing date: Date) -> DateInterval? {
        let day = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .hour, value: startHour, to: day),
              let end = calendar.date(byAdding: .hour, value: endHour, to: day),
              end > start else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }
}
