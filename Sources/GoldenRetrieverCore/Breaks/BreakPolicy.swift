import Foundation

public struct BreakPolicy: Equatable, Sendable {
    /// 0 means the break is due right away.
    public static let workMinutesRange = 0...180
    public static let restMinutesRange = 1...60

    public let workInterval: TimeInterval
    public let restInterval: TimeInterval
    public let warningWindow: TimeInterval

    public init(
        workInterval: TimeInterval = 45 * 60,
        restInterval: TimeInterval = 10 * 60,
        warningWindow: TimeInterval = 5 * 60
    ) {
        self.workInterval = workInterval
        self.restInterval = restInterval
        self.warningWindow = warningWindow
    }

    /// The pounce warning is at most 5 minutes and never more than a quarter
    /// of the work interval, so short sessions are not all warning.
    public init(workMinutes: Int, restMinutes: Int) {
        let work = TimeInterval(min(max(workMinutes, Self.workMinutesRange.lowerBound), Self.workMinutesRange.upperBound)) * 60
        let rest = TimeInterval(min(max(restMinutes, Self.restMinutesRange.lowerBound), Self.restMinutesRange.upperBound)) * 60
        self.init(workInterval: work, restInterval: rest, warningWindow: min(5 * 60, work / 4))
    }
}
