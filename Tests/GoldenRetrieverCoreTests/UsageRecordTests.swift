import Foundation
import XCTest
@testable import GoldenRetrieverCore

final class UsageRecordTests: XCTestCase {
    func testUsageRecordKeepsPrivacyModeAndOptionalDetails() {
        let url = URL(string: "https://example.com")!
        let record = UsageRecord(
            start: Date(timeIntervalSince1970: 10),
            end: Date(timeIntervalSince1970: 20),
            activeSeconds: 10,
            mode: .detailed,
            appName: "Safari",
            windowTitle: "Example",
            browserURL: url
        )

        XCTAssertEqual(record.mode, .detailed)
        XCTAssertEqual(record.appName, "Safari")
        XCTAssertEqual(record.windowTitle, "Example")
        XCTAssertEqual(record.browserURL, url)
    }
}
