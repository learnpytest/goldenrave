import XCTest
@testable import GoldenRetrieverCore

final class BreakInvitationTests: XCTestCase {
    private let due = Date(timeIntervalSince1970: 1_000_000)
    private let warning: TimeInterval = 5 * 60

    func testNoInvitationBeforeTheWarningWindow() {
        XCTAssertEqual(BreakInvitation.phase(due: due, warningWindow: warning, now: due.addingTimeInterval(-6 * 60)), .notYet)
    }

    func testInvitesFromFiveMinutesBeforeUntilTenMinutesAfter() {
        let start = due.addingTimeInterval(-warning)

        XCTAssertEqual(BreakInvitation.phase(due: due, warningWindow: warning, now: start), .inviting(since: start))
        XCTAssertEqual(
            BreakInvitation.phase(due: due, warningWindow: warning, now: due.addingTimeInterval(9 * 60)),
            .inviting(since: start)
        )
        XCTAssertEqual(
            BreakInvitation.phase(due: due, warningWindow: warning, now: due.addingTimeInterval(10 * 60)),
            .gaveUp
        )
    }

    func testAfterGivingUpItAsksAgainTwentyMinutesLater() {
        let gaveUpAt = due.addingTimeInterval(10 * 60)
        let nextDue = BreakInvitation.nextDue(afterGivingUpAt: gaveUpAt, warningWindow: warning)

        XCTAssertEqual(nextDue.addingTimeInterval(-warning), gaveUpAt.addingTimeInterval(20 * 60))
    }

    func testPouncesOnlyBrieflyThenRotatesGentleLinesWithMatchingAnimations() {
        let start = due.addingTimeInterval(-warning)

        XCTAssertEqual(BreakInvitation.animation(since: start, now: start.addingTimeInterval(5)), .pounce)
        let first = BreakInvitation.line(since: start, now: start.addingTimeInterval(BreakInvitation.pounceLength + 1))
        let second = BreakInvitation.line(
            since: start,
            now: start.addingTimeInterval(BreakInvitation.pounceLength + BreakInvitation.lineLength + 1)
        )
        XCTAssertNotEqual(first.text, second.text)
        XCTAssertEqual(
            BreakInvitation.animation(since: start, now: start.addingTimeInterval(BreakInvitation.pounceLength + 1)),
            first.animation
        )
        XCTAssertFalse(BreakInvitation.lines.contains { $0.animation == .pounce || $0.animation == .run })
    }

    func testTheHugLineUsesTheCuddleAnimation() {
        XCTAssertEqual(BreakInvitation.lines.first { $0.text.contains("抱抱") }?.animation, .cuddle)
    }

    func testTheTimeWatchLineUsesTheDedicatedTimeWatchAnimation() {
        XCTAssertEqual(BreakInvitation.lines.first { $0.text == "我幫你看著時間" }?.animation, .timeWatch)
    }

    func testUsesTheSixChosenLines() {
        XCTAssertEqual(BreakInvitation.lines.map(\.text), [
            "你已經工作好久了，要不要陪我一下？",
            "我在這裡等你，想休息時叫我喔",
            "我有點想你了，有空來摸摸我嗎？",
            "忙完這段再來找我就好",
            "你專心好久了，我等你的抱抱喔",
            "我幫你看著時間"
        ])
    }
}
