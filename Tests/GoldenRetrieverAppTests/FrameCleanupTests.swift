import XCTest
@testable import GoldenRetrieverApp

final class FrameCleanupTests: XCTestCase {
    /// 10x6 alpha mask: a 4x4 dog in the middle, a 1-pixel-wide sliver on the
    /// right edge (a neighbouring frame's leftovers), and a 2x2 ball that does
    /// not touch the edge.
    private let width = 10
    private let height = 6
    private func mask() -> [UInt8] {
        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 1...4 { for x in 2...5 { alpha[y * width + x] = 255 } }
        for y in 0...2 { alpha[y * width + 9] = 255 }
        for y in 3...4 { for x in 7...7 { alpha[y * width + x] = 255 } }
        return alpha
    }

    func testDropsSmallFragmentsThatTouchTheCanvasEdge() {
        let keep = FrameCleanup.keepMask(alpha: mask(), width: width, height: height)

        XCTAssertFalse(keep[0 * width + 9], "edge sliver should be removed")
        XCTAssertTrue(keep[2 * width + 3], "the dog stays")
    }

    func testKeepsSeparateObjectsInsideTheFrameLikeTheBall() {
        let keep = FrameCleanup.keepMask(alpha: mask(), width: width, height: height)

        XCTAssertTrue(keep[3 * width + 7], "the ball is not a sliver")
    }

    func testKeepsTheDogEvenWhenItTouchesTheEdge() {
        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0...5 { for x in 0...4 { alpha[y * width + x] = 255 } }

        let keep = FrameCleanup.keepMask(alpha: alpha, width: width, height: height)

        XCTAssertTrue(keep[0])
    }

    func testBoundingBoxCoversOnlyKeptPixels() {
        let keep = FrameCleanup.keepMask(alpha: mask(), width: width, height: height)

        XCTAssertEqual(
            FrameCleanup.boundingBox(of: keep, width: width, height: height),
            FrameCleanup.PixelRect(minX: 2, minY: 1, maxX: 7, maxY: 4)
        )
    }

    func testUnionOfBoxesSpansEveryFrame() {
        let union = FrameCleanup.PixelRect(minX: 2, minY: 1, maxX: 5, maxY: 4)
            .union(FrameCleanup.PixelRect(minX: 0, minY: 3, maxX: 3, maxY: 5))

        XCTAssertEqual(union, FrameCleanup.PixelRect(minX: 0, minY: 1, maxX: 5, maxY: 5))
    }
}
