import XCTest
@testable import GoldenRetrieverApp
import GoldenRetrieverCore

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

    func testASpotHalfOffTheScreenIsPushedBackInside() {
        let origin = FloatingPuppyPlacement.origin(saved: CGPoint(x: 1400, y: -40), size: size, screens: [screen])

        XCTAssertEqual(origin, CGPoint(x: 1440 - 180, y: 0))
    }

    func testTheBubbleShowsOnlyTheFirstHalfOfALine() {
        XCTAssertEqual(FloatingPuppyPlacement.teaser("我有點想你了，有空來摸摸我嗎？"), "我有點想你了…")
        XCTAssertEqual(FloatingPuppyPlacement.teaser("我幫你看著時間"), "我幫你看著時間")
    }

    func testThePopoverContinuesTheBubbleWithTheSecondHalf() {
        XCTAssertEqual(FloatingPuppyPlacement.remainder("我有點想你了，有空來摸摸我嗎？"), "…有空來摸摸我嗎？")
        XCTAssertEqual(FloatingPuppyPlacement.remainder("我幫你看著時間"), "我幫你看著時間", "a line the bubble already shows whole stays whole")
    }

    func testTheDepletedLineSplitsBetweenBubbleAndPopover() {
        XCTAssertEqual(FloatingPuppyPlacement.teaser(BreakInvitation.depletedLine), "金金沒電了…")
        XCTAssertEqual(FloatingPuppyPlacement.remainder(BreakInvitation.depletedLine), "…陪我充個電好嗎？")
    }
}
