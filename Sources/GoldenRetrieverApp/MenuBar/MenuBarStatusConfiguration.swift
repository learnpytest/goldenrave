import Foundation
import GoldenRetrieverCore

struct MenuBarStatusConfiguration: Equatable {
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
        case .idle:
            "golden-retriever-puppy-reference"
        case .walk:
            "walk"
        case .run:
            "run"
        case .play:
            "play"
        case .jump:
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
