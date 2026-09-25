import GoldenRetrieverCore
import SwiftUI

public struct DogAnimationView: View {
    public let state: DogState
    public let player: DogAnimationPlayer
    @State private var isAnimating = false

    public init(state: DogState, player: DogAnimationPlayer = DogAnimationPlayer()) {
        self.state = state
        self.player = player
    }

    public var body: some View {
        Group {
            if let frame = player.frames(for: state).first {
                frame
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotation))
                    .offset(y: verticalOffset)
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.orange)
            }
        }
        .animation(.easeInOut(duration: animationDuration), value: isAnimating)
        .onAppear { isAnimating = true }
        .onChange(of: state) { _, _ in isAnimating.toggle() }
    }

    private var animationDuration: Double {
        switch state {
        case .idle: 1.4
        case .walk: 0.24
        case .run: 0.12
        case .play: 0.35
        case .jump: 0.4
        case .rest: 2.0
        }
    }

    private var scale: CGFloat {
        guard isAnimating else { return 1 }
        return state == .rest ? 1.02 : 1.0
    }

    private var rotation: Double {
        guard isAnimating else { return 0 }
        switch state {
        case .walk, .run: return 2
        case .play: return -3
        default: return 0
        }
    }

    private var verticalOffset: CGFloat {
        guard isAnimating else { return 0 }
        switch state {
        case .jump: return -4
        case .walk, .run, .play: return 2
        default: return 0
        }
    }
}
