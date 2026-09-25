import XCTest
@testable import GoldenRetrieverCore

final class AppIdentityTests: XCTestCase {
    func testBundleIdentifierIsStable() {
        XCTAssertEqual(AppIdentity.bundleIdentifier, "com.rachelchen.GoldenRetriever")
    }
}
