import CoreGraphics
import Foundation
import GoldenRetrieverCore

public struct SystemActivitySource: ActivitySource {
    /// kCGAnyInputEventType. Querying `.null` measures time since the last
    /// null event, which is minutes old even while the user is typing.
    static let anyInputEventType = CGEventType(rawValue: ~UInt32(0))!

    public let idleThreshold: TimeInterval
    private let secondsSinceLastInput: () -> TimeInterval

    public init(
        idleThreshold: TimeInterval = 60,
        secondsSinceLastInput: @escaping () -> TimeInterval = {
            CGEventSource.secondsSinceLastEventType(
                .combinedSessionState,
                eventType: SystemActivitySource.anyInputEventType
            )
        }
    ) {
        self.idleThreshold = idleThreshold
        self.secondsSinceLastInput = secondsSinceLastInput
    }

    public func sample(at date: Date) -> ActivitySample {
        let kind: ActivityKind = secondsSinceLastInput() >= idleThreshold ? .idle : .active
        return ActivitySample(timestamp: date, kind: kind)
    }
}
