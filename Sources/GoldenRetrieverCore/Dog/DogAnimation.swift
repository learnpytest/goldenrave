import Foundation

/// What the puppy is visibly doing. `DogState` is the sustained state derived
/// from usage; spin, belly-up and the play rewards are short moments layered on top.
public enum DogAnimation: String, CaseIterable, Sendable {
    case idle
    case walk
    case run
    case pounce
    case spin
    case rest
    case bellyUp = "belly-up"
    case play
    case playBall = "play-ball"
}

public struct DogAnimationDirector: Sendable {
    public static let spinDuration: TimeInterval = 2.4
    public static let rewardDuration: TimeInterval = 4
    public static let bellyUpCycle: TimeInterval = 75
    public static let bellyUpLength: TimeInterval = 5

    private struct Reward: Sendable {
        let animation: DogAnimation
        let until: Date
    }

    private var breakStartedAt: Date?
    private var reward: Reward?

    public init() {}

    public mutating func breakStarted(at date: Date) {
        breakStartedAt = date
        reward = nil
    }

    /// Only a break that ran its full length earns the play reward.
    public mutating func breakCompleted(at date: Date, withBall: Bool) {
        breakStartedAt = nil
        reward = Reward(animation: withBall ? .playBall : .play, until: date.addingTimeInterval(Self.rewardDuration))
    }

    public mutating func breakEndedEarly() {
        breakStartedAt = nil
    }

    public func animation(for state: DogState, at now: Date) -> DogAnimation {
        if let reward, now < reward.until {
            return reward.animation
        }
        switch state {
        case .idle:
            return .idle
        case .walk:
            return .walk
        case .run:
            return .run
        case .pounce:
            return .pounce
        case .rest:
            return restAnimation(at: now)
        }
    }

    private func restAnimation(at now: Date) -> DogAnimation {
        guard let breakStartedAt else { return .rest }
        let elapsed = now.timeIntervalSince(breakStartedAt)
        if elapsed < Self.spinDuration {
            return .spin
        }
        let phase = (elapsed - Self.spinDuration).truncatingRemainder(dividingBy: Self.bellyUpCycle)
        return phase >= Self.bellyUpCycle - Self.bellyUpLength ? .bellyUp : .rest
    }
}
