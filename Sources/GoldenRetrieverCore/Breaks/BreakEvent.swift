import Foundation

public enum BreakAction: String, Codable, Equatable, Sendable {
    case started
    case postponed
    case skipped
    case completed
}

public struct BreakEvent: Equatable, Sendable {
    public let date: Date
    public let action: BreakAction

    public init(date: Date, action: BreakAction) {
        self.date = date
        self.action = action
    }
}
