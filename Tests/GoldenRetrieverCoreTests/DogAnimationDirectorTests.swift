import XCTest
@testable import GoldenRetrieverCore

final class DogAnimationDirectorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testSustainedStatesMapToTheirAnimations() {
        let director = DogAnimationDirector()

        XCTAssertEqual(director.animation(for: .idle, at: start), .idle)
        XCTAssertEqual(director.animation(for: .walk, at: start), .walk)
        XCTAssertEqual(director.animation(for: .run, at: start), .run)
        XCTAssertEqual(director.animation(for: .pounce, at: start), .pounce)
        XCTAssertEqual(director.animation(for: .rest, at: start), .rest)
        XCTAssertEqual(director.animation(for: .depleted, at: start), .depleted)
    }

    func testStartingABreakSpinsBeforeLyingDown() {
        var director = DogAnimationDirector()
        director.breakStarted(at: start)

        XCTAssertEqual(director.animation(for: .rest, at: start.addingTimeInterval(1)), .spin)
        XCTAssertEqual(
            director.animation(for: .rest, at: start.addingTimeInterval(DogAnimationDirector.spinDuration + 1)),
            .rest
        )
    }

    func testRestingPuppyRollsOntoItsBellyNowAndThen() {
        var director = DogAnimationDirector()
        director.breakStarted(at: start)
        let cycleEnd = DogAnimationDirector.spinDuration + DogAnimationDirector.bellyUpCycle

        XCTAssertEqual(director.animation(for: .rest, at: start.addingTimeInterval(cycleEnd - 1)), .bellyUp)
        XCTAssertEqual(director.animation(for: .rest, at: start.addingTimeInterval(cycleEnd + 1)), .rest)
    }

    func testCompletedBreakEarnsAPlayRewardThatThenEnds() {
        var director = DogAnimationDirector()
        director.breakStarted(at: start)
        director.breakCompleted(at: start, withBall: true)

        XCTAssertEqual(director.animation(for: .walk, at: start.addingTimeInterval(1)), .playBall)
        XCTAssertEqual(
            director.animation(for: .walk, at: start.addingTimeInterval(DogAnimationDirector.rewardDuration + 1)),
            .walk
        )

        director.breakCompleted(at: start, withBall: false)
        XCTAssertEqual(director.animation(for: .idle, at: start.addingTimeInterval(1)), .play)
    }

    func testMomentsReportWhenTheyStartedSoTheyPlayFromTheFirstFrame() {
        var director = DogAnimationDirector()
        director.breakStarted(at: start)

        XCTAssertEqual(
            director.playback(for: .rest, at: start.addingTimeInterval(1)),
            DogAnimationPlayback(animation: .spin, startedAt: start)
        )

        let bellyUpStart = start.addingTimeInterval(
            DogAnimationDirector.spinDuration + DogAnimationDirector.bellyUpCycle - DogAnimationDirector.bellyUpLength
        )
        XCTAssertEqual(
            director.playback(for: .rest, at: bellyUpStart.addingTimeInterval(2)).startedAt?.timeIntervalSince1970 ?? 0,
            bellyUpStart.timeIntervalSince1970,
            accuracy: 0.001
        )

        director.breakCompleted(at: start, withBall: true)
        XCTAssertEqual(
            director.playback(for: .walk, at: start.addingTimeInterval(1)),
            DogAnimationPlayback(animation: .playBall, startedAt: start)
        )
        XCTAssertNil(director.playback(for: .walk, at: start.addingTimeInterval(10)).startedAt)
    }

    func testPlayingTogetherAlternatesPlayAndBall() {
        var director = DogAnimationDirector()
        director.breakStarted(at: start, activity: .play)

        XCTAssertEqual(director.animation(for: .rest, at: start.addingTimeInterval(1)), .play)
        XCTAssertEqual(
            director.animation(for: .rest, at: start.addingTimeInterval(DogAnimationDirector.playSegment + 1)),
            .playBall
        )
    }

    func testGoingForAWalkStrolls() {
        var director = DogAnimationDirector()
        director.breakStarted(at: start, activity: .walk)

        XCTAssertEqual(director.animation(for: .rest, at: start.addingTimeInterval(30)), .stroll)
    }

    func testRelaxingPuppyAlwaysKeepsItsBallAndNeverPounces() {
        let director = DogAnimationDirector()
        let seen = Set((0..<200).map { director.animation(for: .relaxing, at: start.addingTimeInterval(Double($0))) })

        XCTAssertFalse(seen.contains(.pounce))
        XCTAssertFalse(seen.contains(.run))
        XCTAssertEqual(seen, [.playBall], "self-play must keep a ball visible throughout the loop")
    }

    func testInvitationPouncesOnceThenShowsTheLineAnimation() {
        var director = DogAnimationDirector()
        director.invitation(startedAt: start)

        XCTAssertEqual(director.playback(for: .pounce, at: start.addingTimeInterval(3)), DogAnimationPlayback(animation: .pounce, startedAt: start))
        let later = start.addingTimeInterval(BreakInvitation.pounceLength + 2)
        XCTAssertEqual(director.animation(for: .pounce, at: later), BreakInvitation.line(since: start, now: later).animation)
    }

    func testEndingABreakEarlyEarnsNoReward() {
        var director = DogAnimationDirector()
        director.breakStarted(at: start)
        director.breakEndedEarly()

        XCTAssertEqual(director.animation(for: .walk, at: start.addingTimeInterval(1)), .walk)
    }

    func testAStoppedBreakActivityWaitsAndResumesWhereItWas() {
        var director = DogAnimationDirector()
        let start = Date(timeIntervalSince1970: 0)
        director.breakStarted(at: start, activity: .walk)

        director.breakActivity(paused: true)
        XCTAssertEqual(director.animation(for: .rest, at: start.addingTimeInterval(30)), .waiting)

        director.breakActivity(paused: false)
        XCTAssertEqual(director.animation(for: .rest, at: start.addingTimeInterval(40)), .stroll)
    }

    func testChoosingAnotherActivityClearsTheStop() {
        var director = DogAnimationDirector()
        let start = Date(timeIntervalSince1970: 0)
        director.breakStarted(at: start, activity: .walk)
        director.breakActivity(paused: true)

        director.breakStarted(at: start.addingTimeInterval(60), activity: .walk)

        XCTAssertEqual(director.animation(for: .rest, at: start.addingTimeInterval(70)), .stroll)
    }
}
