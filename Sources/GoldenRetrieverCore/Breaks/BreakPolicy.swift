import Foundation

public struct BreakPolicy: Equatable, Sendable {
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
}
