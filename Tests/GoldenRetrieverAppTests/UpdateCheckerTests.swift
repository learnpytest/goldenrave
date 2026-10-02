import XCTest
@testable import GoldenRetrieverApp

final class UpdateCheckerTests: XCTestCase {
    private func release(_ tag: String) -> Data {
        Data(#"{"tag_name":"\#(tag)","html_url":"https://github.com/learnpytest/goldenrave/releases/tag/\#(tag)","draft":false}"#.utf8)
    }

    private func releaseWithDMG(_ tag: String) -> Data {
        Data(#"{"tag_name":"\#(tag)","html_url":"https://github.com/learnpytest/goldenrave/releases/tag/\#(tag)","assets":[{"name":"goldenrave.dmg","browser_download_url":"https://github.com/learnpytest/goldenrave/releases/download/\#(tag)/goldenrave.dmg"}]}"#.utf8)
    }

    func testANewerReleaseIsOfferedWithItsPage() {
        let update = UpdateChecker.update(fromLatestRelease: release("v0.2.0"), currentVersion: "0.1.0")

        XCTAssertEqual(update?.version, "0.2.0")
        XCTAssertEqual(update?.pageURL.absoluteString, "https://github.com/learnpytest/goldenrave/releases/tag/v0.2.0")
    }

    func testAReleaseDMGIsAvailableForInAppUpdate() {
        let update = UpdateChecker.update(fromLatestRelease: releaseWithDMG("v0.2.0"), currentVersion: "0.1.0")

        XCTAssertEqual(update?.downloadURL?.absoluteString, "https://github.com/learnpytest/goldenrave/releases/download/v0.2.0/goldenrave.dmg")
    }

    func testTheSameOrAnOlderReleaseIsNotOffered() {
        XCTAssertNil(UpdateChecker.update(fromLatestRelease: release("v0.1.0"), currentVersion: "0.1.0"))
        XCTAssertNil(UpdateChecker.update(fromLatestRelease: release("v0.0.5"), currentVersion: "0.1.0"))
    }

    func testAnUnexpectedResponseIsIgnored() {
        XCTAssertNil(UpdateChecker.update(fromLatestRelease: Data(#"{"message":"Not Found"}"#.utf8), currentVersion: "0.1.0"))
    }
}
