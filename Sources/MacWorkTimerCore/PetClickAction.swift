import Foundation

public enum PetClickAction: Equatable, Sendable {
    case openLogin
    case revealCapsule
    case showStatusMessage

    public static func action(for revealDisplay: PetRevealDisplay) -> PetClickAction {
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
