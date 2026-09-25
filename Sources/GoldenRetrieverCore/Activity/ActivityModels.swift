import Foundation

public enum ActivityKind: Equatable, Sendable {
    case active
    case idle
}

public struct ActivitySample: Equatable, Sendable {
    public let timestamp: Date
    public let kind: ActivityKind

    public init(timestamp: Date, kind: ActivityKind) {
        self.timestamp = timestamp
        self.kind = kind
    }
}

public struct UsageSnapshot: Equatable, Sendable {
    public let isActive: Bool
    public let currentSession: TimeInterval
    public let todayTotal: TimeInterval

    public init(isActive: Bool, currentSession: TimeInterval, todayTotal: TimeInterval) {
        self.isActive = isActive
        self.currentSession = currentSession
        self.todayTotal = todayTotal
    }
}
