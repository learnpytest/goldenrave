import XCTest
@testable import GoldenRetrieverApp
@testable import GoldenRetrieverCore

final class AppPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "AppPreferencesTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testDefaultsAreFortyFiveMinutesWorkTenMinutesRestAndPrivate() {
        let preferences = AppPreferences(defaults: defaults)

        XCTAssertEqual(preferences.workMinutes, 45)
        XCTAssertEqual(preferences.restMinutes, 10)
        XCTAssertEqual(preferences.trackingMode, .privateMode)
        XCTAssertEqual(preferences.breakPolicy, BreakPolicy())
    }

    func testChoicesSurviveARelaunch() {
        var preferences = AppPreferences(defaults: defaults)
        preferences.workMinutes = 25
        preferences.restMinutes = 5
        preferences.trackingMode = .detailed

        let relaunched = AppPreferences(defaults: defaults)
        XCTAssertEqual(relaunched.workMinutes, 25)
        XCTAssertEqual(relaunched.restMinutes, 5)
        XCTAssertEqual(relaunched.trackingMode, .detailed)
        XCTAssertEqual(relaunched.breakPolicy, BreakPolicy(workMinutes: 25, restMinutes: 5))
    }

    func testFloatingPuppyPositionIsUnsetUntilDraggedThenRemembered() {
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertNil(preferences.floatingPuppyOrigin)

        preferences.floatingPuppyOrigin = CGPoint(x: 120, y: 340)

        XCTAssertEqual(AppPreferences(defaults: defaults).floatingPuppyOrigin, CGPoint(x: 120, y: 340))
    }
}
