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

    public static func stage(
        elapsed: TimeInterval?,
        duration: TimeInterval,
        stageCount: Int = 3
    ) -> PetEvolutionStage {
        let index = stageIndex(elapsed: elapsed, duration: duration, stageCount: stageCount)
        return stage(forStageIndex: index, stageCount: stageCount)
    }

    public static func stageIndex(
        elapsed: TimeInterval?,
        duration: TimeInterval,
        stageCount: Int
    ) -> Int {
        guard stageCount > 0, duration > 0, let elapsed else {
            return 0
        }

        let clampedElapsed = min(max(0, elapsed), duration)
        if clampedElapsed >= duration {
            return stageCount - 1
        }

        let stageDuration = duration / Double(stageCount)
        return min(stageCount - 1, Int((clampedElapsed / stageDuration).rounded(.down)))
    }

    public static func stage(forStageIndex index: Int, stageCount: Int) -> PetEvolutionStage {
        guard stageCount > 1 else {
            return .base
        }

        let clampedIndex = min(max(0, index), stageCount - 1)
        if clampedIndex == 0 {
            return .base
        }
        if clampedIndex == stageCount - 1 {
            return .final
        }
        return .middle
    }

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
