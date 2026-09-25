import XCTest
@testable import GoldenRetrieverApp

final class PermissionCoordinatorTests: XCTestCase {
    func testPermissionErrorExplainsWhatToDoNext() {
        let error = DetailedActivityPermissionError()

        XCTAssertTrue(error.explanation.contains("Accessibility"))
        XCTAssertTrue(error.recoveryAction.contains("System Settings"))
    }
}
