import Foundation
import GoldenRetrieverCore

struct MenuBarStatusConfiguration: Equatable {
    /// Widest menu bar puppy (40pt) plus the "00:00" timer.
    static let minimumLength: Double = 86

    let imageResourceName: String
    let title: String
    let accessibilityLabel: String

    init(snapshot: UsageSnapshot, dogState: DogState) {
        imageResourceName = Self.resourceName(for: dogState)
        title = Self.format(snapshot.currentSession)
        accessibilityLabel = "小黃金目前陪你工作 \(title)"
    }

    private static func resourceName(for state: DogState) -> String {
        switch state {
        case .idle, .walk:
            "walk"
        case .run:
            "run"
        case .pounce:
            "jump"
        case .rest:
            "rest"
        }
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
