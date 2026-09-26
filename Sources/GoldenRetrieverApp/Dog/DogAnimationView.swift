import GoldenRetrieverCore
import SwiftUI

public struct DogAnimationView: View {
    private let animationAt: (Date) -> DogAnimation
    private let player: DogAnimationPlayer

    public init(
        animationAt: @escaping (Date) -> DogAnimation,
        player: DogAnimationPlayer = DogAnimationPlayer()
    ) {
        self.animationAt = animationAt
        self.player = player
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            let animation = animationAt(context.date)
            let frames = player.frames(for: animation)
            if frames.isEmpty {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.orange)
            } else {
                let index = DogAnimationPlayer.frameIndex(
                    elapsed: context.date.timeIntervalSinceReferenceDate,
                    frameDuration: player.frameDuration(for: animation),
                    frameCount: frames.count
                )
                Image(nsImage: frames[index])
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}
