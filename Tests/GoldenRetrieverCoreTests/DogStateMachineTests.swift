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

    func testActivePuppyPlaysAfterThirtyMinutesOutsideWarningWindow() {
        XCTAssertEqual(machine.state(for: input(session: 30 * 60)), .play)
    }

    func testWarningWindowMapsToJump() {
        XCTAssertEqual(machine.state(for: input(session: 30 * 60, untilBreak: 5 * 60)), .jump)
        XCTAssertEqual(machine.state(for: input(session: 30 * 60, untilBreak: 0)), .jump)
    }

    func testBreakMapsToRest() {
        XCTAssertEqual(machine.state(for: input(session: 30 * 60, onBreak: true)), .rest)
    }
}
