import Foundation

public struct WindowSize: Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum MainWindowMetrics {
    public static func contentSize(hasSession: Bool, showsLogin: Bool = false) -> WindowSize {
        hasSession && !showsLogin
            ? WindowSize(width: 430, height: 160)
            : WindowSize(width: 620, height: 560)
    }
}
