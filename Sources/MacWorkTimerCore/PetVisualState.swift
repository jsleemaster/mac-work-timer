import Foundation

public enum PetDragState: Equatable, Sendable {
    case idle
    case pressed
    case left
    case right
}

public enum PetLabelTone: Equatable, Sendable {
    case neutral
    case warm
    case done
}

public struct PetVisualState: Equatable, Sendable {
    public let label: String
    public let frameSetName: String
    public let frameDuration: TimeInterval
    public let labelTone: PetLabelTone

    public static func make(
        remaining: TimeInterval?,
        elapsed: TimeInterval?,
        now: Date,
        calendar: Calendar = .current,
        dragState: PetDragState = .idle,
        temporaryMessage: String? = nil
    ) -> PetVisualState {
        let mood = PetMood.mood(remaining: remaining)
        let frameSetName = frameSetName(for: mood, now: now, calendar: calendar, dragState: dragState)
        let label = temporaryMessage ?? defaultLabel(for: mood, remaining: remaining)

        return PetVisualState(
            label: label,
            frameSetName: frameSetName,
            frameDuration: frameDuration(for: mood, dragState: dragState),
            labelTone: labelTone(for: mood)
        )
    }

    public static func clickMessage(remaining: TimeInterval?, elapsed: TimeInterval?) -> String {
        switch PetMood.mood(remaining: remaining) {
        case .idle:
            return "출근 대기"
        case .working:
            return "조용히 가는 중"
        case .under1h:
            return "1시간 안쪽"
        case .under30m:
            return "마무리 구간"
        case .under5m:
            return "정리하자"
        case .done:
            return "퇴근 가능"
        }
    }

    public static func timeText(_ interval: TimeInterval?) -> String {
        guard let interval else {
            return "--"
        }

        let seconds = max(0, Int(interval.rounded()))
        if seconds < 60 {
            return "\(seconds)초"
        }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }

        return "\(minutes)분"
    }

    public static func leaveTimeText(
        targetAt: Date?,
        timeZone: TimeZone = TimeZone(identifier: "Asia/Seoul")!
    ) -> String? {
        guard let targetAt else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: targetAt)
        let minute = calendar.component(.minute, from: targetAt)
        return String(format: "퇴근 %02d:%02d", hour, minute)
    }

    private static func defaultLabel(for mood: PetMood, remaining: TimeInterval?) -> String {
        switch mood {
        case .idle:
            return "출근 대기"
        case .working, .under1h, .under30m:
            return "남은 \(timeText(remaining))"
        case .under5m:
            return "퇴근까지 \(timeText(remaining))"
        case .done:
            return "퇴근 가능"
        }
    }

    private static func frameSetName(
        for mood: PetMood,
        now: Date,
        calendar: Calendar,
        dragState: PetDragState
    ) -> String {
        switch dragState {
        case .pressed:
            return "drag"
        case .left:
            return "drag-left"
        case .right:
            return "drag-right"
        case .idle:
            break
        }

        switch mood {
        case .idle:
            return "idle"
        case .working:
            return workingFrameSetName(now: now, calendar: calendar)
        case .under1h:
            return "under1h"
        case .under30m:
            return "under30m"
        case .under5m:
            return "under5m"
        case .done:
            return "done"
        }
    }

    private static func workingFrameSetName(now: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: now)
        if hour >= 15 {
            return "working-late"
        }
        if hour >= 12 {
            return "working-afternoon"
        }
        return "working"
    }

    private static func frameDuration(for mood: PetMood, dragState: PetDragState) -> TimeInterval {
        switch dragState {
        case .pressed:
            return 0.18
        case .left, .right:
            return 0.10
        case .idle:
            break
        }

        switch mood {
        case .idle:
            return 0.34
        case .working:
            return 0.30
        case .under1h:
            return 0.24
        case .under30m:
            return 0.18
        case .under5m:
            return 0.12
        case .done:
            return 0.14
        }
    }

    private static func labelTone(for mood: PetMood) -> PetLabelTone {
        switch mood {
        case .under5m:
            return .warm
        case .done:
            return .done
        default:
            return .neutral
        }
    }
}
