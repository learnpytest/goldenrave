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

    func testMotionStatesHaveDifferentCadences() {
        let player = DogAnimationPlayer()

        XCTAssertNotEqual(player.frameDuration(for: .walk), player.frameDuration(for: .run))
        XCTAssertNotEqual(player.frameDuration(for: .run), player.frameDuration(for: .rest))
    }
}
