import CoreGraphics
import GoldenRetrieverCore
import XCTest
@testable import GoldenRetrieverApp

final class SystemActivitySourceTests: XCTestCase {
    func testQueriesAnyInputEventTypeInsteadOfNullEvents() {
        XCTAssertEqual(SystemActivitySource.anyInputEventType.rawValue, UInt32.max)
        XCTAssertNotEqual(SystemActivitySource.anyInputEventType, .null)
    }

    func testRecentInputCountsAsActive() {
        let source = SystemActivitySource(idleThreshold: 60, secondsSinceLastInput: { 5 })

        XCTAssertEqual(source.sample(at: Date()).kind, .active)
    }

    func testNoInputPastThresholdCountsAsIdle() {
        let source = SystemActivitySource(idleThreshold: 60, secondsSinceLastInput: { 120 })

        XCTAssertEqual(source.sample(at: Date()).kind, .idle)
    }
}
