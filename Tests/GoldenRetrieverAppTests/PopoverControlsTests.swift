import XCTest
@testable import GoldenRetrieverApp

final class PopoverControlsTests: XCTestCase {
    func testOnBreakOnlyOffersEndingTheBreakEarly() {
        XCTAssertEqual(
            PopoverView.controls(isOnBreak: true, remindersPaused: false, hasScheduledBreak: false),
            [.endBreak]
        )
    }

    func testWorkingOffersStartAndPauseWithoutAnyPostpone() {
        for hasScheduledBreak in [true, false] {
            XCTAssertEqual(
                PopoverView.controls(isOnBreak: false, remindersPaused: false, hasScheduledBreak: hasScheduledBreak),
                [.startBreak, .pauseReminders]
            )
        }
    }

    func testPausedRemindersCanBeResumed() {
        XCTAssertEqual(
            PopoverView.controls(isOnBreak: false, remindersPaused: true, hasScheduledBreak: false),
            [.startBreak, .resumeReminders]
        )
    }

    func testReminderButtonsSayTheyAreAboutBreakReminders() {
        XCTAssertEqual(PopoverControl.pauseReminders.title, "暫停休息提醒")
        XCTAssertEqual(PopoverControl.resumeReminders.title, "恢復休息提醒")
    }

    func testBreakCountdownRoundsUpRemainingMinutes() {
        let now = Date(timeIntervalSince1970: 0)
        let endsAt = now.addingTimeInterval(6 * 60 + 10)

        XCTAssertEqual(PopoverView.remainingBreakMinutes(until: endsAt, now: now), 7)
        XCTAssertEqual(PopoverView.remainingBreakMinutes(until: now.addingTimeInterval(-5), now: now), 0)
    }
}
