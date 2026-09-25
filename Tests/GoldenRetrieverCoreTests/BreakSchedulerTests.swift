import Foundation
import XCTest
@testable import GoldenRetrieverCore

final class BreakSchedulerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testDefaultWorkIntervalAndWarningPolicy() {
        let scheduler = BreakScheduler()

        XCTAssertEqual(scheduler.nextBreak(after: start), start.addingTimeInterval(45 * 60))
        XCTAssertEqual(BreakPolicy().warningWindow, 5 * 60)
        XCTAssertEqual(BreakPolicy().restInterval, 10 * 60)
    }

    func testPostponingMovesDueDateByRestInterval() {
        let scheduler = BreakScheduler()

        XCTAssertEqual(
            scheduler.apply(.postponed, at: start),
            start.addingTimeInterval(10 * 60)
        )
    }

    func testSkippingStartsANewWorkInterval() {
        let scheduler = BreakScheduler()

        XCTAssertEqual(
            scheduler.apply(.skipped, at: start),
            start.addingTimeInterval(45 * 60)
        )
    }

    func testCompletingBreakIncludesRestAndNextWorkInterval() {
        let scheduler = BreakScheduler()

        XCTAssertEqual(
            scheduler.apply(.completed, at: start),
            start.addingTimeInterval(55 * 60)
        )
    }

    func testStartedDoesNotInventAnotherDueDate() {
        XCTAssertNil(BreakScheduler().apply(.started, at: start))
    }

    func testScheduleWorksAcrossMidnight() {
        let lateNight = Date(timeIntervalSince1970: 86_390)

        XCTAssertEqual(
            BreakScheduler().nextBreak(after: lateNight),
            Date(timeIntervalSince1970: 89_090)
        )
    }
}
