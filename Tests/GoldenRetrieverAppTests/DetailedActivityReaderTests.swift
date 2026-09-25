import Foundation
import XCTest
@testable import GoldenRetrieverApp

final class DetailedActivityReaderTests: XCTestCase {
    private struct DeniedPermission: PermissionCoordinator {
        var canReadDetailedActivity: Bool { false }
        func requestDetailedActivityPermission() {}
    }

    func testFrontmostReaderReturnsNilWithoutPermission() {
        let reader = FrontmostAppReader(permission: DeniedPermission())

        XCTAssertNil(reader.read())
    }

    func testUnsupportedBrowserDoesNotInventURL() {
        XCTAssertNil(BrowserTabReader().readURL())
    }
}
