import Foundation

public enum PetClickAction: Equatable, Sendable {
    case openLogin
    case revealCapsule
    case showStatusMessage

    public static func action(
        for revealDisplay: PetRevealDisplay,
        needsWeeklyLoginRecovery: Bool = false
    ) -> PetClickAction {
        if needsWeeklyLoginRecovery {
            return .openLogin
        }
        switch revealDisplay {
        case .idle:
            return .openLogin
        case .capsuleIdle:
            return .revealCapsule
        case .petVisible:
            return .showStatusMessage
        }
    }
}
