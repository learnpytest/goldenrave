import Foundation

/// The 連續使用 the user sees. A break is not work, and the next stretch of
/// work starts when the break ends, so the next 喘口氣 is counted from there
/// instead of inviting again right after a break spent at the computer.
/// Usage statistics still record the real activity.
public enum WorkSessionClock {
    public static func session(engineSession: TimeInterval, isOnBreak: Bool, countsFrom: Date?, now: Date) -> TimeInterval {
        if isOnBreak { return 0 }
        guard let countsFrom else { return engineSession }
        return min(engineSession, max(0, now.timeIntervalSince(countsFrom)))
    }
}
