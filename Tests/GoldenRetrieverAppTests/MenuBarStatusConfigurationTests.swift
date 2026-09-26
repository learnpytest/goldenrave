import GoldenRetrieverCore
import XCTest
@testable import GoldenRetrieverApp

final class MenuBarStatusConfigurationTests: XCTestCase {
    func testConfigurationMapsRunningDogAndSessionDurationToStatusItem() {
        let configuration = MenuBarStatusConfiguration(
            snapshot: UsageSnapshot(isActive: true, currentSession: 42, todayTotal: 42),
            dogState: .run
        )

        XCTAssertEqual(configuration.imageResourceName, "run")
        XCTAssertEqual(configuration.title, "00:42")
        XCTAssertEqual(configuration.accessibilityLabel, "小黃金目前陪你工作 00:42")
    }

    func testConfigurationClampsNegativeDurationAndUsesRestImage() {
        let configuration = MenuBarStatusConfiguration(
            snapshot: UsageSnapshot(isActive: false, currentSession: -1, todayTotal: 0),
            dogState: .rest
        )

        XCTAssertEqual(configuration.imageResourceName, "rest")
        XCTAssertEqual(configuration.title, "00:00")
    }
}
