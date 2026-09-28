import XCTest
@testable import GoldenRetrieverCore

final class AppVersionTests: XCTestCase {
    func testReadsTagsWithOrWithoutAV() {
        XCTAssertEqual(AppVersion("v0.2.0"), AppVersion("0.2.0"))
        XCTAssertNil(AppVersion("nightly"))
    }

    func testComparesNumerically() {
        XCTAssertTrue(AppVersion("0.10.0")! > AppVersion("0.9.1")!)
        XCTAssertTrue(AppVersion("1.0")! > AppVersion("0.99.9")!)
        XCTAssertEqual(AppVersion("1.0")!, AppVersion("1.0.0")!, "missing parts count as zero")
    }

    func testAnUpdateIsOnlyOfferedForANewerRelease() {
        XCTAssertTrue(AppVersion.isUpdate(latestTag: "v0.2.0", current: "0.1.0"))
        XCTAssertFalse(AppVersion.isUpdate(latestTag: "v0.1.0", current: "0.1.0"))
        XCTAssertFalse(AppVersion.isUpdate(latestTag: "v0.0.9", current: "0.1.0"))
        XCTAssertFalse(AppVersion.isUpdate(latestTag: "draft", current: "0.1.0"), "an unreadable tag is never an update")
    }
}
