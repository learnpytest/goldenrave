import GoldenRetrieverCore
import SwiftUI

public struct DogAnimationView: View {
    private let playbackAt: (Date) -> DogAnimationPlayback
    private let player: DogAnimationPlayer

    public init(
        playbackAt: @escaping (Date) -> DogAnimationPlayback,
        player: DogAnimationPlayer = DogAnimationPlayer()
    ) {
        self.playbackAt = playbackAt
        self.player = player
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            let playback = playbackAt(context.date)
            let animation = playback.animation
            let frames = player.frames(for: animation)
            if frames.isEmpty {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.orange)
            } else {
                let index = DogAnimationPlayer.frameIndex(
                    elapsed: context.date.timeIntervalSince(playback.startedAt ?? Date(timeIntervalSinceReferenceDate: 0)),
                    frameDuration: player.frameDuration(for: animation),
                    frameCount: frames.count,
                    loops: player.loops(animation)
                )
                Image(nsImage: frames[index])
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}
