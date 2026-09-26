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
    /// Going for a walk together (on a lead), as opposed to the work-session `walk`.
    case stroll
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
    public static let playSegment: TimeInterval = 8
    /// Paused reminders: a quiet loop of the puppy's own business.
    static let relaxingLoop: [(animation: DogAnimation, length: TimeInterval)] = [
        (.rest, 40), (.bellyUp, 5), (.idle, 30), (.playBall, 8), (.rest, 7)
    ]

    private struct Reward: Sendable {
        let animation: DogAnimation
        let until: Date
    }

    private var breakStartedAt: Date?
    private var breakActivity: BreakActivity = .rest
    private var reward: Reward?

    public init() {}

    public mutating func breakStarted(at date: Date, activity: BreakActivity = .rest) {
        breakStartedAt = date
        breakActivity = activity
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
            switch breakActivity {
            case .rest: return restPlayback(at: now)
            case .play: return playPlayback(at: now)
            case .walk: return DogAnimationPlayback(animation: .stroll)
            }
        case .relaxing:
            return relaxingPlayback(at: now)
        }
    }

    private func playPlayback(at now: Date) -> DogAnimationPlayback {
        guard let breakStartedAt else { return DogAnimationPlayback(animation: .play) }
        let elapsed = max(0, now.timeIntervalSince(breakStartedAt))
        let segment = (elapsed / Self.playSegment).rounded(.down)
        let startedAt = breakStartedAt.addingTimeInterval(segment * Self.playSegment)
        let animation: DogAnimation = Int(segment) % 2 == 0 ? .play : .playBall
        return DogAnimationPlayback(animation: animation, startedAt: startedAt)
    }

    private func relaxingPlayback(at now: Date) -> DogAnimationPlayback {
        let cycle = Self.relaxingLoop.reduce(0) { $0 + $1.length }
        var phase = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        if phase < 0 { phase += cycle }
        for step in Self.relaxingLoop {
            if phase < step.length {
                return DogAnimationPlayback(animation: step.animation, startedAt: now.addingTimeInterval(-phase))
            }
            phase -= step.length
        }
        return DogAnimationPlayback(animation: .rest)
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
