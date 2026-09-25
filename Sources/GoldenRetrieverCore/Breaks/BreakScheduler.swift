import Foundation

public struct BreakScheduler: Sendable {
    public let policy: BreakPolicy
    public let calendar: Calendar

    public init(policy: BreakPolicy = BreakPolicy(), calendar: Calendar = .current) {
        self.policy = policy
        self.calendar = calendar
    }

    public func nextBreak(after sessionStart: Date) -> Date {
        sessionStart.addingTimeInterval(policy.workInterval)
    }

    public func apply(_ action: BreakAction, at date: Date) -> Date? {
        switch action {
        case .started:
            return nil
        case .postponed:
            return date.addingTimeInterval(policy.restInterval)
        case .skipped:
            return nextBreak(after: date)
        case .completed:
            return date
                .addingTimeInterval(policy.restInterval)
                .addingTimeInterval(policy.workInterval)
        }
    }
}
