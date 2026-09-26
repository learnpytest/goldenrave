import XCTest
@testable import GoldenRetrieverApp

final class FloatingPuppyPlacementTests: XCTestCase {
    private let size = CGSize(width: 180, height: 160)
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)

    func testFirstAppearanceIsTheBottomRightCornerOfTheScreen() {
        let origin = FloatingPuppyPlacement.origin(saved: nil, size: size, screens: [screen])

        XCTAssertEqual(origin, CGPoint(x: 1440 - 180 - 24, y: 24))
    }

    func testARememberedSpotIsReused() {
        let origin = FloatingPuppyPlacement.origin(saved: CGPoint(x: 300, y: 400), size: size, screens: [screen])

        XCTAssertEqual(origin, CGPoint(x: 300, y: 400))
    }

    func testASpotOnADisconnectedScreenFallsBackToTheCorner() {
        let origin = FloatingPuppyPlacement.origin(saved: CGPoint(x: 3000, y: 400), size: size, screens: [screen])

        XCTAssertEqual(origin, CGPoint(x: 1440 - 180 - 24, y: 24))
    }

    func testATinyWobbleIsAClickButMovingFurtherIsADrag() {
        XCTAssertFalse(FloatingPuppyPlacement.isDrag(from: .zero, to: CGPoint(x: 2, y: 2)))
        XCTAssertTrue(FloatingPuppyPlacement.isDrag(from: .zero, to: CGPoint(x: 6, y: 0)))
    }
}
