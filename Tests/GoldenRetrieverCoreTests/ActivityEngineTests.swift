import Foundation
import XCTest
@testable import GoldenRetrieverCore

final class ActivityEngineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }

    func testActiveSamplesAccumulateAndIdleClosesSession() {
        var engine = ActivityEngine(calendar: calendar)

        _ = engine.ingest(ActivitySample(timestamp: date(0), kind: .active))
        let active = engine.ingest(ActivitySample(timestamp: date(10), kind: .active))
        XCTAssertTrue(active.isActive)
        XCTAssertEqual(active.currentSession, 10, accuracy: 0.001)
        XCTAssertEqual(active.todayTotal, 10, accuracy: 0.001)

        let idle = engine.ingest(ActivitySample(timestamp: date(20), kind: .idle))
        XCTAssertFalse(idle.isActive)
        XCTAssertEqual(idle.currentSession, 0, accuracy: 0.001)
        XCTAssertEqual(idle.todayTotal, 20, accuracy: 0.001)
    }

    func testIdleGapIsNotCountedAsActiveTime() {
        var engine = ActivityEngine(calendar: calendar)

        _ = engine.ingest(ActivitySample(timestamp: date(0), kind: .active))
        _ = engine.ingest(ActivitySample(timestamp: date(10), kind: .idle))
        _ = engine.ingest(ActivitySample(timestamp: date(70), kind: .active))
        let active = engine.ingest(ActivitySample(timestamp: date(75), kind: .active))

        XCTAssertEqual(active.currentSession, 5, accuracy: 0.001)
        XCTAssertEqual(active.todayTotal, 15, accuracy: 0.001)
    }

    func testActiveSessionCrossingMidnightIsSplitAcrossDays() {
        var engine = ActivityEngine(calendar: calendar)
        let beforeMidnight = date(86_390)
        let afterMidnight = date(86_410)

        _ = engine.ingest(ActivitySample(timestamp: beforeMidnight, kind: .active))
        let snapshot = engine.ingest(ActivitySample(timestamp: afterMidnight, kind: .active))

        XCTAssertEqual(snapshot.currentSession, 20, accuracy: 0.001)
        XCTAssertEqual(snapshot.todayTotal, 10, accuracy: 0.001)
        XCTAssertEqual(engine.total(on: beforeMidnight), 10, accuracy: 0.001)
        XCTAssertEqual(engine.total(on: afterMidnight), 10, accuracy: 0.001)
    }
}
