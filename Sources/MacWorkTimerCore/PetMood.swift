import Foundation

public enum PetMood: Equatable, Sendable {
    case idle
    case working
    case under1h
    case under30m
    case under5m
    case done

    public static func mood(remaining: TimeInterval?) -> PetMood {
        guard let remaining else {
            return .idle
        }

        let seconds = max(0, Int(remaining.rounded()))
        if seconds == 0 {
            return .done
        }

        if seconds < 5 * 60 {
            return .under5m
        }

        if seconds < 30 * 60 {
            return .under30m
        }

        if seconds < 60 * 60 {
            return .under1h
        }

        return .working
    }
}

public enum PetEvolutionStage: Equatable, Sendable {
    case base
    case middle
    case `final`

    public static func stage(mood: PetMood) -> PetEvolutionStage {
        switch mood {
        case .idle, .working:
            return .base
        case .under1h, .under30m:
            return .middle
        case .under5m, .done:
            return .final
        }
    }
}
