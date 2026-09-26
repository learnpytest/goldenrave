import Foundation
import XCTest
@testable import GoldenRetrieverApp
@testable import GoldenRetrieverCore

final class TrackingModeTests: XCTestCase {
    private final class FakeReader: DetailedActivityReader {
        var readCount = 0
        var segment: ActivitySegment?

        func read() -> ActivitySegment? {
            readCount += 1
            return segment
        }
    }

    private final class FakePermission: PermissionCoordinator {
        var canReadDetailedActivity: Bool
        var requestCount = 0
        var grantOnRequest = false

        init(canRead: Bool) {
            self.canReadDetailedActivity = canRead
        }

        func requestDetailedActivityPermission() {
            requestCount += 1
            canReadDetailedActivity = grantOnRequest
        }
    }

    private final class FakeStore: DetailedActivityStore {
        var segments: [ActivitySegment] = []

        func save(segment: ActivitySegment) throws {
            segments.append(segment)
        }
    }

    func testGrantingPermissionAfterTheRequestSwitchesToDetailed() {
        let permission = FakePermission(canRead: false)
        let controller = TrackingModeController(reader: FakeReader(), permission: permission, store: FakeStore())

        XCTAssertThrowsError(try controller.enableDetailedMode())
        XCTAssertTrue(controller.isAwaitingPermission)
        XCTAssertFalse(controller.refreshPermission())

        permission.canReadDetailedActivity = true
        XCTAssertTrue(controller.refreshPermission())
        XCTAssertEqual(controller.mode, .detailed)
        XCTAssertFalse(controller.isAwaitingPermission)
    }

    func testChoosingPrivateCancelsAPendingDetailedRequest() {
        let permission = FakePermission(canRead: false)
        let controller = TrackingModeController(reader: FakeReader(), permission: permission, store: FakeStore())

        XCTAssertThrowsError(try controller.enableDetailedMode())
        controller.disableDetailedMode()
        permission.canReadDetailedActivity = true

        XCTAssertFalse(controller.refreshPermission())
        XCTAssertEqual(controller.mode, .privateMode)
    }

    func testRestoringDetailedWithoutPermissionWaitsForIt() {
        let permission = FakePermission(canRead: false)
        let controller = TrackingModeController(
            reader: FakeReader(),
            permission: permission,
            store: FakeStore(),
            mode: .detailed
        )

        XCTAssertEqual(controller.mode, .privateMode)
        XCTAssertTrue(controller.isAwaitingPermission)
        permission.canReadDetailedActivity = true
        XCTAssertTrue(controller.refreshPermission())
        XCTAssertEqual(controller.mode, .detailed)
    }

    func testPrivateModeNeverCallsReaderOrStoresSegment() throws {
        let reader = FakeReader()
        let permission = FakePermission(canRead: true)
        let store = FakeStore()
        let controller = TrackingModeController(reader: reader, permission: permission, store: store)

        XCTAssertNil(try controller.capture())
        XCTAssertEqual(reader.readCount, 0)
        XCTAssertTrue(store.segments.isEmpty)
    }

    func testEnablingDetailedModeWithoutPermissionReturnsRecoveryError() {
        let reader = FakeReader()
        let permission = FakePermission(canRead: false)
        let store = FakeStore()
        let controller = TrackingModeController(reader: reader, permission: permission, store: store)

        XCTAssertThrowsError(try controller.enableDetailedMode()) { error in
            XCTAssertEqual(error as? DetailedActivityPermissionError, DetailedActivityPermissionError())
        }
        XCTAssertEqual(controller.mode, .privateMode)
        XCTAssertTrue(store.segments.isEmpty)
    }

    func testUnsupportedBrowserStillStoresAppAndWindow() throws {
        let reader = FakeReader()
        reader.segment = ActivitySegment(
            timestamp: Date(timeIntervalSince1970: 10),
            appName: "TextEdit",
            windowTitle: "Notes",
            browserURL: nil
        )
        let permission = FakePermission(canRead: true)
        let store = FakeStore()
        let controller = TrackingModeController(reader: reader, permission: permission, store: store)
        try controller.enableDetailedMode()

        _ = try controller.capture()

        XCTAssertEqual(store.segments.count, 1)
        XCTAssertEqual(store.segments.first?.appName, "TextEdit")
        XCTAssertEqual(store.segments.first?.windowTitle, "Notes")
        XCTAssertNil(store.segments.first?.browserURL)
    }
}
