import XCTest
@testable import GoldenRetrieverCore

final class WorkSessionClockTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000)

    func testABreakDoesNotCountAsWork() {
        XCTAssertEqual(WorkSessionClock.session(engineSession: 3_000, isOnBreak: true, countsFrom: nil, now: now), 0)
    }

    func testAfterABreakTheSessionCountsFromWhenItEnded() {
        let ended = now.addingTimeInterval(-120)

        XCTAssertEqual(WorkSessionClock.session(engineSession: 3_000, isOnBreak: false, countsFrom: ended, now: now), 120)
    }

    func testAFreshSessionAfterSteppingAwayIsNotStretched() {
        let ended = now.addingTimeInterval(-600)

        XCTAssertEqual(WorkSessionClock.session(engineSession: 90, isOnBreak: false, countsFrom: ended, now: now), 90)
    }

    func testWithoutABreakTheEngineSessionIsUsed() {
        XCTAssertEqual(WorkSessionClock.session(engineSession: 500, isOnBreak: false, countsFrom: nil, now: now), 500)
    }
}
