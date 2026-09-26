import XCTest
@testable import GoldenRetrieverApp
@testable import GoldenRetrieverCore

final class DogAnimationPlayerTests: XCTestCase {
    func testEveryAnimationHasAtLeastOneFrame() {
        let player = DogAnimationPlayer()

        for animation in DogAnimation.allCases {
            XCTAssertFalse(player.frames(for: animation).isEmpty, "Missing frames for \(animation)")
        }
    }

    func testCanonicalReferenceIsPackaged() {
        XCTAssertNotNil(DogAnimationPlayer.canonicalReferenceURL())
    }

    func testMenuBarFramesFitInTheMenuBar() {
        let player = DogAnimationPlayer()

        for animation in DogAnimation.allCases {
            let frames = player.menuBarFrames(for: animation)
            XCTAssertFalse(frames.isEmpty, "Missing menu bar frames for \(animation)")
            for frame in frames {
                XCTAssertLessThanOrEqual(frame.size.height, 22, "Menu bar frame too tall for \(animation)")
                XCTAssertLessThanOrEqual(frame.size.width, 40, "Menu bar frame too wide for \(animation)")
            }
        }
    }

    func testIdleDoesNotUseTheMultiPoseReferenceSheet() {
        XCTAssertFalse(DogAnimationPlayer.frameURLs(for: .idle).contains { $0 == DogAnimationPlayer.canonicalReferenceURL() })
    }

    func testFrameIndexLoopsThroughTheSequence() {
        XCTAssertEqual(DogAnimationPlayer.frameIndex(elapsed: 0, frameDuration: 0.1, frameCount: 4), 0)
        XCTAssertEqual(DogAnimationPlayer.frameIndex(elapsed: 0.25, frameDuration: 0.1, frameCount: 4), 2)
        XCTAssertEqual(DogAnimationPlayer.frameIndex(elapsed: 0.45, frameDuration: 0.1, frameCount: 4), 0)
        XCTAssertEqual(DogAnimationPlayer.frameIndex(elapsed: 5, frameDuration: 0.1, frameCount: 1), 0)
    }

    func testSpinPlaysOnceAndSettlesOnItsLastFrame() {
        let player = DogAnimationPlayer()
        let frameCount = player.frames(for: .spin).count
        let duration = player.frameDuration(for: .spin)

        XCTAssertFalse(player.loops(.spin))
        XCTAssertEqual(duration * Double(frameCount), DogAnimationDirector.spinDuration, accuracy: 0.01)
        XCTAssertEqual(
            DogAnimationPlayer.frameIndex(elapsed: 10, frameDuration: duration, frameCount: frameCount, loops: false),
            frameCount - 1
        )
    }

    func testFastMotionsCycleFasterThanCalmOnes() {
        let player = DogAnimationPlayer()

        XCTAssertLessThan(player.frameDuration(for: .run), player.frameDuration(for: .walk))
        XCTAssertLessThan(player.frameDuration(for: .walk), player.frameDuration(for: .rest))
    }
}
