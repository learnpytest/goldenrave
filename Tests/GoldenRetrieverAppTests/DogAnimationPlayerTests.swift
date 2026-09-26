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
                XCTAssertLessThanOrEqual(frame.size.height, DogAnimationPlayer.menuBarHeight, "too tall: \(animation)")
                XCTAssertLessThanOrEqual(frame.size.width, DogAnimationPlayer.menuBarMaxWidth, "too wide: \(animation)")
                XCTAssertTrue(
                    frame.size.height >= 20 || frame.size.width >= DogAnimationPlayer.menuBarMaxWidth - 1,
                    "The dog should fill the menu bar, got \(frame.size) for \(animation)"
                )
            }
            XCTAssertEqual(Set(frames.map(\.size)).count, 1, "Frames of \(animation) should share one size")
        }
    }

    func testMenuBarFramesArePreRenderedAtMenuBarResolution() throws {
        let frame = try XCTUnwrap(DogAnimationPlayer().menuBarFrames(for: .run).first)
        let rep = try XCTUnwrap(frame.representations.first)

        XCTAssertEqual(frame.representations.count, 1)
        XCTAssertLessThanOrEqual(rep.pixelsHigh, Int(DogAnimationPlayer.menuBarHeight) * 2, "Menu bar frames should not keep the full-size bitmap")
    }

    func testMenuBarSwapsFramesAtMostAboutSevenTimesASecondButRunStaysFasterThanWalk() {
        let player = DogAnimationPlayer()

        for animation in DogAnimation.allCases where animation != .spin {
            XCTAssertGreaterThanOrEqual(
                player.menuBarFrameDuration(for: animation),
                DogAnimationPlayer.menuBarMinimumFrameDuration,
                "\(animation)"
            )
        }
        XCTAssertLessThan(player.menuBarFrameDuration(for: .run), player.menuBarFrameDuration(for: .walk))
        XCTAssertEqual(player.menuBarFrameDuration(for: .spin), player.frameDuration(for: .spin))
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
