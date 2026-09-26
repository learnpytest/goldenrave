import XCTest
@testable import GoldenRetrieverApp

final class PopoverControlsTests: XCTestCase {
    func testOnBreakOnlyOffersEndingTheBreakEarly() {
        XCTAssertEqual(
            PopoverView.controls(isOnBreak: true, remindersPaused: false, hasScheduledBreak: false),
            [.endBreak]
        )
    }

    func testWorkingWithScheduledBreakOffersStartPostponeAndPause() {
        XCTAssertEqual(
            PopoverView.controls(isOnBreak: false, remindersPaused: false, hasScheduledBreak: true),
            [.startBreak, .postpone, .pauseReminders]
        )
    }

    func testWorkingWithoutScheduledBreakHidesPostpone() {
        XCTAssertEqual(
            PopoverView.controls(isOnBreak: false, remindersPaused: false, hasScheduledBreak: false),
            [.startBreak, .pauseReminders]
        )
    }

    func testPausedRemindersCanBeResumed() {
        XCTAssertEqual(
            PopoverView.controls(isOnBreak: false, remindersPaused: true, hasScheduledBreak: false),
            [.startBreak, .resumeReminders]
        )
    }

    func testPostponeLabelSaysWhatIsPostponed() {
        XCTAssertEqual(PopoverControl.postpone.title, "休息延後 10 分鐘")
    }

    func testBreakCountdownRoundsUpRemainingMinutes() {
        let now = Date(timeIntervalSince1970: 0)
        let endsAt = now.addingTimeInterval(6 * 60 + 10)

        XCTAssertEqual(PopoverView.remainingBreakMinutes(until: endsAt, now: now), 7)
        XCTAssertEqual(PopoverView.remainingBreakMinutes(until: now.addingTimeInterval(-5), now: now), 0)
    }
}
