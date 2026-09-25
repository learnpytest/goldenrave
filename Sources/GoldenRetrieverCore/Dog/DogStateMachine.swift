import Foundation

public struct DogStateInput: Equatable, Sendable {
    public let isActive: Bool
    public let sessionDuration: TimeInterval
    public let secondsUntilBreak: TimeInterval?
    public let isOnBreak: Bool

    public init(
        isActive: Bool,
        sessionDuration: TimeInterval,
        secondsUntilBreak: TimeInterval?,
        isOnBreak: Bool
    ) {
        self.isActive = isActive
        self.sessionDuration = sessionDuration
        self.secondsUntilBreak = secondsUntilBreak
        self.isOnBreak = isOnBreak
    }
}

public struct DogStateMachine: Sendable {
    public let policy: BreakPolicy

    public init(policy: BreakPolicy) {
        self.policy = policy
    }

    public func state(for input: DogStateInput) -> DogState {
        if input.isOnBreak {
            return .rest
        }
        guard input.isActive else {
            return .idle
        }
        if let secondsUntilBreak = input.secondsUntilBreak,
           secondsUntilBreak <= policy.warningWindow {
            return .jump
        }
        if input.sessionDuration < 5 * 60 {
            return .walk
        }
        if input.sessionDuration < 30 * 60 {
            return .run
        }
        return .play
    }
}
