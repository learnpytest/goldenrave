import XCTest
@testable import GoldenRetrieverApp
@testable import GoldenRetrieverCore

final class DogAnimationPlayerTests: XCTestCase {
    func testEveryVisualStateHasAFrame() {
        let player = DogAnimationPlayer()

        for state in DogState.allCases {
            XCTAssertFalse(player.frames(for: state).isEmpty, "Missing frame for \(state)")
        }
    }

    func testCanonicalReferenceAndMotionResourcesExist() {
        XCTAssertNotNil(DogAnimationPlayer.canonicalReferenceURL())
        for state in [DogState.walk, .run, .play, .jump, .rest] {
            XCTAssertNotNil(DogAnimationPlayer.resourceURL(for: state), "Missing resource for \(state)")
        }
    }

    func testMenuBarImageFitsInTheMenuBar() throws {
        let player = DogAnimationPlayer()

        for state in DogState.allCases {
            let image = try XCTUnwrap(player.menuBarImage(for: state), "Missing menu bar image for \(state)")
            XCTAssertLessThanOrEqual(image.size.height, 22, "Menu bar image too tall for \(state)")
            XCTAssertLessThanOrEqual(image.size.width, 40, "Menu bar image too wide for \(state)")
        }
    }

    func testIdleDoesNotUseTheMultiPoseReferenceSheet() {
        XCTAssertNotEqual(DogAnimationPlayer.resourceURL(for: .idle), DogAnimationPlayer.canonicalReferenceURL())
    }

    func testMotionStatesHaveDifferentCadences() {
        let player = DogAnimationPlayer()

        XCTAssertNotEqual(player.frameDuration(for: .walk), player.frameDuration(for: .run))
        XCTAssertNotEqual(player.frameDuration(for: .run), player.frameDuration(for: .rest))
    }
}
