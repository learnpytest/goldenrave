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

/// `startedAt` is set for moments so they play from their first frame;
/// sustained loops have no start and follow the wall clock.
public struct DogAnimationPlayback: Equatable, Sendable {
    public let animation: DogAnimation
    public let startedAt: Date?

    public init(animation: DogAnimation, startedAt: Date? = nil) {
        self.animation = animation
        self.startedAt = startedAt
    }
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
        playback(for: state, at: now).animation
    }

    public func playback(for state: DogState, at now: Date) -> DogAnimationPlayback {
        if let reward, now < reward.until {
            return DogAnimationPlayback(
                animation: reward.animation,
                startedAt: reward.until.addingTimeInterval(-Self.rewardDuration)
            )
        }
        switch state {
        case .idle:
            return DogAnimationPlayback(animation: .idle)
        case .walk:
            return DogAnimationPlayback(animation: .walk)
        case .run:
            return DogAnimationPlayback(animation: .run)
        case .pounce:
            return DogAnimationPlayback(animation: .pounce)
        case .rest:
            return restPlayback(at: now)
        }
    }

    private func restPlayback(at now: Date) -> DogAnimationPlayback {
        guard let breakStartedAt else { return DogAnimationPlayback(animation: .rest) }
        let elapsed = now.timeIntervalSince(breakStartedAt)
        if elapsed < Self.spinDuration {
            return DogAnimationPlayback(animation: .spin, startedAt: breakStartedAt)
        }
        let phase = (elapsed - Self.spinDuration).truncatingRemainder(dividingBy: Self.bellyUpCycle)
        let bellyUpBegins = Self.bellyUpCycle - Self.bellyUpLength
        if phase >= bellyUpBegins {
            return DogAnimationPlayback(animation: .bellyUp, startedAt: now.addingTimeInterval(-(phase - bellyUpBegins)))
        }
        return DogAnimationPlayback(animation: .rest)
    }
}
