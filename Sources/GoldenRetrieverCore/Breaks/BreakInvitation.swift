import Foundation

/// How the puppy asks for company around a due break: one short pounce,
/// then gentle rotating lines; if nobody answers within ten minutes of the
/// due time it stops asking and tries again twenty minutes later.
public enum BreakInvitation {
    public enum Phase: Equatable, Sendable {
        case notYet
        case inviting(since: Date)
        case gaveUp
    }

    public struct Line: Equatable, Sendable {
        public let text: String
        public let animation: DogAnimation
    }

    public static let pounceLength: TimeInterval = 10
    public static let lineLength: TimeInterval = 45
    public static let overdueGrace: TimeInterval = 10 * 60
    public static let retryAfter: TimeInterval = 20 * 60

    /// Shown once the invitation has been ignored to the end and 小金金 is
    /// out of battery; the break stays due.
    public static let depletedLine = "金金沒電了，等你來摸摸就能充電"

    public static let lines: [Line] = [
        Line(text: "你已經工作好久了，要不要陪我一下？", animation: .play),
        Line(text: "我在這裡等你，想休息時叫我喔", animation: .waiting),
        Line(text: "我有點想你了，有空來摸摸我嗎？", animation: .bellyUp),
        Line(text: "忙完這段再來找我就好", animation: .waiting),
        Line(text: "你專心好久了，我等你的抱抱喔", animation: .cuddle),
        Line(text: "我幫你看著時間", animation: .timeWatch)
    ]

    public static func phase(due: Date, warningWindow: TimeInterval, now: Date) -> Phase {
        let start = due.addingTimeInterval(-warningWindow)
        if now < start { return .notYet }
        if now >= due.addingTimeInterval(overdueGrace) { return .gaveUp }
        return .inviting(since: start)
    }

    /// The next due time chosen so the invitation starts again `retryAfter` from now.
    public static func nextDue(afterGivingUpAt date: Date, warningWindow: TimeInterval) -> Date {
        date.addingTimeInterval(retryAfter + warningWindow)
    }

    public static func line(since start: Date, now: Date) -> Line {
        let elapsed = max(0, now.timeIntervalSince(start) - pounceLength)
        return lines[Int(elapsed / lineLength) % lines.count]
    }

    public static func animation(since start: Date, now: Date) -> DogAnimation {
        now.timeIntervalSince(start) < pounceLength ? .pounce : line(since: start, now: now).animation
    }

    /// When the current pounce or line began, so its animation starts at frame 1.
    public static func segmentStart(since start: Date, now: Date) -> Date {
        let elapsed = now.timeIntervalSince(start)
        guard elapsed >= pounceLength else { return start }
        let lineIndex = ((elapsed - pounceLength) / lineLength).rounded(.down)
        return start.addingTimeInterval(pounceLength + lineIndex * lineLength)
    }
}
