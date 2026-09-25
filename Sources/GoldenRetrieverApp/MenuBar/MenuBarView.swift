import GoldenRetrieverCore
import SwiftUI

public struct MenuBarView: View {
    public let snapshot: UsageSnapshot
    public let dogState: DogState
    public let player: DogAnimationPlayer

    public init(
        snapshot: UsageSnapshot,
        dogState: DogState,
        player: DogAnimationPlayer = DogAnimationPlayer()
    ) {
        self.snapshot = snapshot
        self.dogState = dogState
        self.player = player
    }

    public var body: some View {
        HStack(spacing: 5) {
            DogAnimationView(state: dogState, player: player)
                .frame(width: 22, height: 22)
            Text(Self.format(snapshot.currentSession))
                .monospacedDigit()
                .font(.caption2)
        }
        .accessibilityLabel("小黃金目前陪你工作 \(Self.format(snapshot.currentSession))")
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
