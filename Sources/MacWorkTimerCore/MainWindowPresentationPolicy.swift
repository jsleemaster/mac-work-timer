import Foundation

public enum MainWindowPresentationPolicy {
    public static let shouldShowMainWindowOnLaunch = false

    public static func needsWeeklyLoginRecovery(
        hasSession: Bool,
        hasCompleteWeeklySummary: Bool
    ) -> Bool {
        hasSession && !hasCompleteWeeklySummary
    }

    public static func shouldOpenLoginWindow(
        hasSession: Bool,
        needsWeeklyLoginRecovery: Bool = false
    ) -> Bool {
        !hasSession || needsWeeklyLoginRecovery
    }

    public static func shouldHideMainWindow(
        hasSession: Bool,
        needsWeeklyLoginRecovery: Bool = false
    ) -> Bool {
        hasSession && !needsWeeklyLoginRecovery
    }
}
