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

    func testTimeWatchUsesItsDedicatedFourFrameSequence() {
        XCTAssertEqual(DogAnimationPlayer.frameURLs(for: .timeWatch).count, 4)
        XCTAssertFalse(DogAnimationPlayer.frameURLs(for: .timeWatch).contains { $0.lastPathComponent == "rest.png" })
    }

    func testWaitingUsesItsDedicatedEightFrameSequence() {
        XCTAssertEqual(DogAnimationPlayer.frameURLs(for: .waiting).count, 8)
        XCTAssertFalse(DogAnimationPlayer.frameURLs(for: .waiting).contains { $0.lastPathComponent == "rest.png" })
    }

    func testDepletedUsesItsDedicatedFourFrameSequence() {
        XCTAssertEqual(DogAnimationPlayer.frameURLs(for: .depleted).count, 4)
        XCTAssertFalse(DogAnimationPlayer.frameURLs(for: .depleted).contains { $0.lastPathComponent == "rest.png" })
    }

    func testPounceUsesTheEightFrameBellyUpBasedSequence() {
        XCTAssertEqual(DogAnimationPlayer.frameURLs(for: .pounce).count, 8)
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
                    frame.size.height >= DogAnimationPlayer.menuBarHeight - 1 || frame.size.width >= DogAnimationPlayer.menuBarMaxWidth - 1,
                    "The dog should fill the menu bar, got \(frame.size) for \(animation)"
                )
            }
            XCTAssertTrue(frames.allSatisfy { $0.size == frames[0].size }, "Frames of \(animation) should share one size")
        }
    }

    func testMenuBarFramesArePreRenderedAtMenuBarResolution() throws {
        let frame = try XCTUnwrap(DogAnimationPlayer().menuBarFrames(for: .run).first)
        let rep = try XCTUnwrap(frame.representations.first)

        XCTAssertEqual(frame.representations.count, 1)
        XCTAssertLessThanOrEqual(rep.pixelsHigh, Int(DogAnimationPlayer.menuBarHeight) * 2, "Menu bar frames should not keep the full-size bitmap")
    }

    func testMenuBarSwapsFramesAtMostAboutSevenTimesASecond() {
        let player = DogAnimationPlayer()

        for animation in DogAnimation.allCases where animation != .spin {
            XCTAssertGreaterThanOrEqual(
                player.menuBarFrameDuration(for: animation),
                DogAnimationPlayer.menuBarMinimumFrameDuration,
                "\(animation)"
            )
        }
        XCTAssertEqual(player.menuBarFrameDuration(for: .spin), player.frameDuration(for: .spin))
        XCTAssertEqual(player.menuBarFrameDuration(for: .run), 0.3, accuracy: 0.0001)
        XCTAssertEqual(player.menuBarFrameDuration(for: .play), 0.25, accuracy: 0.0001)
        XCTAssertEqual(player.menuBarFrameDuration(for: .walk), 0.57, accuracy: 0.0001)
    }

    func testPopoverFramesArePreScaledToThePopoverSize() throws {
        let frames = DogAnimationPlayer().popoverFrames(for: .walk)
        let frame = try XCTUnwrap(frames.first)

        XCTAssertLessThanOrEqual(frame.size.height, DogAnimationPlayer.popoverSide)
        XCTAssertLessThanOrEqual(frame.size.width, DogAnimationPlayer.popoverSide)
        XCTAssertLessThanOrEqual(try XCTUnwrap(frame.representations.first).pixelsHigh, Int(DogAnimationPlayer.popoverSide) * 2)
    }

    /// Guards against drawing into only the bottom-left quarter of the @2x
    /// bitmap, which made the menu bar and popover puppies half size.
    func testPreScaledFramesFillTheirWholeBitmap() throws {
        let player = DogAnimationPlayer()
        for frames in [player.menuBarFrames(for: .walk), player.popoverFrames(for: .walk)] {
            let frame = try XCTUnwrap(frames.first)
            let rep = try XCTUnwrap(frame.representations.first as? NSBitmapImageRep)
            var minY = rep.pixelsHigh, maxY = -1, maxX = -1
            for y in 0..<rep.pixelsHigh {
                for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 {
                    minY = min(minY, y); maxY = max(maxY, y); maxX = max(maxX, x)
                }
            }
            XCTAssertGreaterThan(Double(maxY - minY + 1), Double(rep.pixelsHigh) * 0.8, "dog should span the frame height")
            XCTAssertGreaterThan(Double(maxX + 1), Double(rep.pixelsWide) * 0.8, "dog should reach the right side")
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

    func testLongRunningMotionsStayCalmSoTheyDoNotDazzle() {
        let player = DogAnimationPlayer()

        for animation: DogAnimation in [.run, .playBall, .cuddle] {
            XCTAssertEqual(player.frameDuration(for: animation), 0.3, accuracy: 0.0001, "\(animation)")
        }
        XCTAssertEqual(player.frameDuration(for: .play), 0.25, accuracy: 0.0001)
        XCTAssertEqual(player.frameDuration(for: .walk), 0.38, accuracy: 0.0001)
        XCTAssertEqual(player.frameDuration(for: .stroll), 0.45, accuracy: 0.0001)
        XCTAssertEqual(player.frameDuration(for: .bellyUp), 0.375, accuracy: 0.0001)
        XCTAssertLessThan(player.frameDuration(for: .walk), player.frameDuration(for: .rest))
    }

    func testPounceUsesTheSmoothPreviewSpeed() {
        XCTAssertEqual(DogAnimationPlayer().frameDuration(for: .pounce), 0.29, accuracy: 0.0001)
    }

    func testTheNextFrameIsScheduledOnItsOwnBoundaryNotAFixedTick() {
        XCTAssertEqual(DogAnimationPlayer.secondsUntilNextFrame(elapsed: 0, frameDuration: 0.15), 0.15, accuracy: 0.0001)
        XCTAssertEqual(DogAnimationPlayer.secondsUntilNextFrame(elapsed: 0.2, frameDuration: 0.15), 0.1, accuracy: 0.0001)
        XCTAssertEqual(DogAnimationPlayer.secondsUntilNextFrame(elapsed: 0.3, frameDuration: 0.15), 0.15, accuracy: 0.0001)
    }
}
