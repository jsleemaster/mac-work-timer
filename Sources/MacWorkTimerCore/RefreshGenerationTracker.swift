public struct RefreshGeneration: Equatable, Sendable {
    fileprivate let value: UInt64
}

public struct RefreshGenerationTracker: Sendable {
    private var currentValue: UInt64 = 0
    private var hasCurrentGeneration = false

    public init() {}

    public mutating func begin() -> RefreshGeneration {
        currentValue &+= 1
        hasCurrentGeneration = true
        return RefreshGeneration(value: currentValue)
    }

    public mutating func invalidate() {
        hasCurrentGeneration = false
    }

    public func isCurrent(_ generation: RefreshGeneration) -> Bool {
        hasCurrentGeneration && generation.value == currentValue
    }
}
