import CoreGraphics
import Foundation
import GoldenRetrieverCore

public struct SystemActivitySource: ActivitySource {
    public let idleThreshold: TimeInterval

    public init(idleThreshold: TimeInterval = 60) {
        self.idleThreshold = idleThreshold
    }

    public func sample(at date: Date) -> ActivitySample {
        let idleSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .null
        )
        let kind: ActivityKind = idleSeconds >= idleThreshold ? .idle : .active
        return ActivitySample(timestamp: date, kind: kind)
    }
}
