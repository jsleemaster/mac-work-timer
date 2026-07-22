import Foundation

public enum PetPanelMetrics {
    public static let width: Double = 330
    public static let height: Double = 188
    public static let labelMaxWidth: Double = 188
    public static let agentUsageGridColumnCount: Int = 2
    public static let agentUsageGridColumnWidth: Double = 96
    public static let agentUsageGridSpacing: Double = 6
    public static let agentUsageGridWidth: Double = (agentUsageGridColumnWidth * 2) + agentUsageGridSpacing
    public static let agentUsagePrimaryFontSize: Double = 15.5
    public static let agentUsageResetPrimaryFontSize: Double = 14.5
    public static let agentUsageSecondaryFontSize: Double = 10.5
    public static let agentUsageProviderFontSize: Double = 7.4
    public static let agentUsageMeterHeight: Double = 7
    public static let agentUsageSpriteOffsetX: Double = -86
    public static let agentUsageGridOffsetX: Double = 62
    public static let agentUsageGridOffsetY: Double = 74
    public static let singleLineSpriteOffsetY: Double = 36
    public static let twoLineSpriteOffsetY: Double = 50
    public static let threeLineSpriteOffsetY: Double = 64
    public static let localSpriteWidth: Double = 90
    public static let localSpriteHeight: Double = 98
    public static let localImageWidth: Double = 84
    public static let localImageHeight: Double = 90
    public static let maxFloatOffset: Double = 2
    public static let maxScale: Double = 1.02
    public static let minimumBottomMargin: Double = 5

    public static func spriteOffsetY(hasLeaveTime: Bool) -> Double {
        spriteOffsetY(labelLineCount: hasLeaveTime ? 2 : 1)
    }

    public static func spriteOffsetY(labelLineCount: Int) -> Double {
        switch labelLineCount {
        case ...1:
            return singleLineSpriteOffsetY
        case 2:
            return twoLineSpriteOffsetY
        default:
            return threeLineSpriteOffsetY
        }
    }

    public static func localSpriteVisualBottom(hasLeaveTime: Bool) -> Double {
        localSpriteVisualBottom(labelLineCount: hasLeaveTime ? 2 : 1)
    }

    public static func localSpriteVisualBottom(labelLineCount: Int) -> Double {
        spriteOffsetY(labelLineCount: labelLineCount) + (localSpriteHeight * maxScale) + maxFloatOffset
    }
}
