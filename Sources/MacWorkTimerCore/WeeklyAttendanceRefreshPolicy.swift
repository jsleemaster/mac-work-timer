public enum WeeklyAttendanceRefreshReason: Sendable {
    case routine
    case authenticatedWebSession
}

public enum WeeklyAttendanceRefreshPolicy {
    public static func shouldStart(
        isRefreshInProgress: Bool,
        reason: WeeklyAttendanceRefreshReason
    ) -> Bool {
        !isRefreshInProgress || reason == .authenticatedWebSession
    }
}
