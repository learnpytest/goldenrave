import XCTest
@testable import GoldenRetrieverCore

final class DogStateMachineTests: XCTestCase {
    private let machine = DogStateMachine(policy: BreakPolicy())

    private func input(
        active: Bool = true,
        session: TimeInterval,
        untilBreak: TimeInterval? = 1_000,
        onBreak: Bool = false
    ) -> DogStateInput {
        DogStateInput(
            isActive: active,
            sessionDuration: session,
            secondsUntilBreak: untilBreak,
            isOnBreak: onBreak
        )
    }

    func testInactiveInputMapsToIdle() {
        XCTAssertEqual(machine.state(for: input(active: false, session: 600)), .idle)
    }

    func testActivePuppyWalksAtTheStartOfASession() {
        XCTAssertEqual(machine.state(for: input(session: 4 * 60 + 59)), .walk)
    }

    func testActivePuppyRunsAfterFiveMinutes() {
        XCTAssertEqual(machine.state(for: input(session: 5 * 60)), .run)
        XCTAssertEqual(machine.state(for: input(session: 29 * 60)), .run)
    }

    func testLongSessionKeepsRunningInsteadOfPlaying() {
        XCTAssertEqual(machine.state(for: input(session: 30 * 60)), .run)
        XCTAssertEqual(machine.state(for: input(session: 90 * 60)), .run)
    }

    func testWarningWindowMapsToPounce() {
        XCTAssertEqual(machine.state(for: input(session: 30 * 60, untilBreak: 5 * 60)), .pounce)
        XCTAssertEqual(machine.state(for: input(session: 30 * 60, untilBreak: 0)), .pounce)
    }

    func testPausedRemindersLeaveThePuppyRelaxingInsteadOfPouncing() {
        let paused = DogStateInput(isActive: true, sessionDuration: 60 * 60, secondsUntilBreak: 0, isOnBreak: false, remindersPaused: true)

        XCTAssertEqual(machine.state(for: paused), .relaxing)
    }

    func testBreakMapsToRest() {
        XCTAssertEqual(machine.state(for: input(session: 30 * 60, onBreak: true)), .rest)
    }
}
