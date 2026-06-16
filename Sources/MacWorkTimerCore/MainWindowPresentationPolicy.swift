import Foundation

public enum MainWindowPresentationPolicy {
    public static let shouldShowMainWindowOnLaunch = false

    public static func shouldOpenLoginWindow(hasSession: Bool) -> Bool {
        !hasSession
    }

    public static func shouldHideMainWindow(hasSession: Bool) -> Bool {
        hasSession
    }
}
