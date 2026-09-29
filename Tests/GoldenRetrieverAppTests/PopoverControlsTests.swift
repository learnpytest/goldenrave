import GoldenRetrieverCore
import XCTest
@testable import GoldenRetrieverApp

final class PopoverControlsTests: XCTestCase {
    func testABreakCanSwitchActivityOrStopButNotEndEarly() {
        XCTAssertEqual(
            PopoverView.controls(isOnBreak: true, remindersPaused: false, hasScheduledBreak: false),
            [.start(.rest), .start(.play), .start(.walk), .stopActivity]
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

    func testThePanelIsCompactNowThatThePuppyLivesInTheMenuBar() {
        XCTAssertLessThanOrEqual(PopoverLayout.size.height, 300, "no empty space where the puppy used to be")
        XCTAssertLessThan(PopoverLayout.mainHeight(showsActionRow: false), PopoverLayout.mainHeight(showsActionRow: true))
        XCTAssertLessThan(PopoverLayout.settingsHeight(showsUpdateHint: false), PopoverLayout.settingsHeight(showsUpdateHint: true))
        XCTAssertLessThan(
            PopoverLayout.settingsHeight(showsUpdateHint: false),
            PopoverLayout.settingsHeight(showsUpdateHint: false, showsPermissionHint: true)
        )
        XCTAssertEqual(SettingsView.accessibilitySettingsURL.scheme, "x-apple.systempreferences")
    }

    func testPetVisibilityOffersHideAndShow() {
        XCTAssertEqual(PetVisibility.allCases.map(\.title), ["Hide", "Show"])
        XCTAssertEqual(PetVisibility(showsPet: true), .show)
        XCTAssertEqual(PetVisibility(showsPet: false), .hide)
    }

    func testBreakCountdownRoundsUpRemainingMinutes() {
        let now = Date(timeIntervalSince1970: 0)
        let endsAt = now.addingTimeInterval(6 * 60 + 10)

        XCTAssertEqual(PopoverView.remainingBreakMinutes(until: endsAt, now: now), 7)
        XCTAssertEqual(PopoverView.remainingBreakMinutes(until: now.addingTimeInterval(-5), now: now), 0)
    }

    func testWhileInvitingTheRowSaysTheBreakIsHereAndKeepsThePlannedTime() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let planned = now.addingTimeInterval(-3 * 60)

        let row = PopoverView.breakRow(nextBreak: planned, isInviting: true, now: now)

        XCTAssertEqual(row.title, "喘口氣時間到了")
        XCTAssertEqual(row.value, PopoverView.timeString(planned))
    }

    func testBeforeTheInvitationTheRowIsThePlainNextBreak() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let planned = now.addingTimeInterval(10 * 60)

        let row = PopoverView.breakRow(nextBreak: planned, isInviting: false, now: now)

        XCTAssertEqual(row.title, "下次喘口氣")
        XCTAssertEqual(row.value, PopoverView.timeString(planned))
    }


    func testEveryControlIsAnIconTitledForTooltips() {
        let all: [PopoverControl] = [.start(.rest), .start(.play), .start(.walk), .pauseReminders, .resumeReminders, .stopActivity, .resumeActivity]
        XCTAssertEqual(Set(all.map(\.systemImage)).count, all.count, "each control has its own icon")
        XCTAssertEqual(PopoverControl.pauseReminders.title, "暫停")
    }

    func testPausedRemindersKeepTheirWayBackAndABreakCanStillEndEarly() {
        let paused = PopoverView.controls(isOnBreak: false, remindersPaused: true, hasScheduledBreak: false)
        let onBreak = PopoverView.controls(isOnBreak: true, remindersPaused: false, hasScheduledBreak: false)

        XCTAssertEqual(PopoverView.visibleControls(paused, isInviting: false), [.resumeReminders])
        XCTAssertEqual(PopoverView.visibleControls(onBreak, isInviting: false, isOnBreak: true), onBreak)
    }

    func testBreakChoicesShowOnlyWhenTheBreakIsDue() {
        let working = PopoverView.controls(isOnBreak: false, remindersPaused: false, hasScheduledBreak: true)

        XCTAssertEqual(PopoverView.visibleControls(working, isInviting: false), [], "pause waits for the break too")
        XCTAssertEqual(PopoverView.visibleControls(working, isInviting: true), [.start(.rest), .start(.play), .start(.walk), .pauseReminders])
    }

    func testAStoppedActivityOffersToContinue() {
        XCTAssertEqual(
            PopoverView.controls(isOnBreak: true, remindersPaused: false, hasScheduledBreak: false, activityPaused: true).last,
            .resumeActivity
        )
    }

    func testTheChoiceRowOnlyShowsWhenThereIsSomethingToChoose() {
        XCTAssertFalse(PopoverView.showsActionRow(isInviting: false, isOnBreak: false, remindersPaused: false))
        XCTAssertTrue(PopoverView.showsActionRow(isInviting: true, isOnBreak: false, remindersPaused: false))
        XCTAssertTrue(PopoverView.showsActionRow(isInviting: false, isOnBreak: true, remindersPaused: false))
        XCTAssertTrue(PopoverView.showsActionRow(isInviting: false, isOnBreak: false, remindersPaused: true), "恢復 stays reachable")
    }
}
