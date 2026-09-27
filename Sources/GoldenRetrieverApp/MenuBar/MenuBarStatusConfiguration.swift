import Foundation
import GoldenRetrieverCore

struct MenuBarStatusConfiguration: Equatable {
    let title: String
    let accessibilityLabel: String

    init(snapshot: UsageSnapshot, dogState: DogState) {
        title = Self.format(snapshot.currentSession)
        accessibilityLabel = "小金金目前陪你工作 \(title)"
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
