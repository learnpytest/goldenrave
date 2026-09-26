import GoldenRetrieverCore
import XCTest
@testable import GoldenRetrieverApp

final class PopoverControlsTests: XCTestCase {
    func testOnBreakOnlyOffersEndingItEarly() {
        XCTAssertEqual(
            PopoverView.controls(isOnBreak: true, remindersPaused: false, hasScheduledBreak: false),
            [.endBreak]
        )
    }

    func testWorkingLetsTheUserChooseRestPlayOrWalkAndPause() {
        for hasScheduledBreak in [true, false] {
            XCTAssertEqual(
                PopoverView.controls(isOnBreak: false, remindersPaused: false, hasScheduledBreak: hasScheduledBreak),
                [.start(.rest), .start(.play), .start(.walk), .pauseReminders]
            )
        }
    }

    func testPausedCanBeResumed() {
        XCTAssertEqual(
            PopoverView.controls(isOnBreak: false, remindersPaused: true, hasScheduledBreak: false),
            [.start(.rest), .start(.play), .start(.walk), .resumeReminders]
        )
    }

    func testButtonsUseShortLabels() {
        XCTAssertEqual(PopoverControl.start(.rest).title, "休息")
        XCTAssertEqual(PopoverControl.start(.play).title, "陪玩")
        XCTAssertEqual(PopoverControl.start(.walk).title, "散步")
        XCTAssertEqual(PopoverControl.pauseReminders.title, "暫停")
    }

    func testADueReminderReadsNowInsteadOfAPastTime() {
        let now = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertEqual(PopoverView.nextBreakText(now.addingTimeInterval(-7 * 60), now: now), "現在")
        XCTAssertEqual(PopoverView.nextBreakText(now, now: now), "現在")
        XCTAssertEqual(
            PopoverView.nextBreakText(now.addingTimeInterval(10 * 60), now: now),
            PopoverView.timeString(now.addingTimeInterval(10 * 60))
        )
        XCTAssertEqual(PopoverView.nextBreakText(nil, now: now), "尚未排程")
    }

    func testBreakCountdownRoundsUpRemainingMinutes() {
        let now = Date(timeIntervalSince1970: 0)
        let endsAt = now.addingTimeInterval(6 * 60 + 10)

        XCTAssertEqual(PopoverView.remainingBreakMinutes(until: endsAt, now: now), 7)
        XCTAssertEqual(PopoverView.remainingBreakMinutes(until: now.addingTimeInterval(-5), now: now), 0)
    }
}
