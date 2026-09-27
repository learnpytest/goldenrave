import Foundation
import XCTest
@testable import GoldenRetrieverApp
@testable import GoldenRetrieverCore
import SwiftData

final class LocalStoreTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }

    private func makeStore() throws -> SwiftDataLocalStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UsageSessionModel.self,
            BreakEventModel.self,
            DetailedActivityModel.self,
            configurations: configuration
        )
        return SwiftDataLocalStore(container: container, calendar: calendar)
    }

    func testDailyTotalAggregatesOnlyTheRequestedDay() throws {
        let store = try makeStore()
        try store.save(session: UsageRecord(start: date(0), end: date(10), activeSeconds: 10, mode: .privateMode))
        try store.save(session: UsageRecord(start: date(20), end: date(35), activeSeconds: 15, mode: .privateMode))
        try store.save(session: UsageRecord(start: date(86_400), end: date(86_410), activeSeconds: 10, mode: .privateMode))

        XCTAssertEqual(try store.dailyTotal(on: date(0)), 25, accuracy: 0.001)
        XCTAssertEqual(try store.dailyTotal(on: date(86_400)), 10, accuracy: 0.001)
    }

    func testCSVHasStableHeadersAndDetailedColumnsOnlyWhenNeeded() throws {
        let store = try makeStore()
        try store.save(session: UsageRecord(start: date(0), end: date(10), activeSeconds: 10, mode: .privateMode))
        let privateCSV = String(data: try store.exportCSV(), encoding: .utf8)!
        XCTAssertTrue(privateCSV.hasPrefix("start,end,active_seconds,tracking_mode\n"))
        XCTAssertFalse(privateCSV.contains("app_name"))

        try store.save(session: UsageRecord(
            start: date(20),
            end: date(30),
            activeSeconds: 10,
            mode: .detailed,
            appName: "Safari",
            windowTitle: "A, title",
            browserURL: URL(string: "https://example.com")
        ))
        let detailedCSV = String(data: try store.exportCSV(), encoding: .utf8)!
        XCTAssertTrue(detailedCSV.contains("app_name,window_title,browser_url"))
        XCTAssertTrue(detailedCSV.contains("\"A, title\""))
    }

    func testDeleteAllRemovesSessionsAndBreakEvents() throws {
        let store = try makeStore()
        try store.save(session: UsageRecord(start: date(0), end: date(10), activeSeconds: 10, mode: .privateMode))
        try store.save(breakEvent: BreakEventRecord(date: date(10), action: .completed))

        try store.deleteAll()

        XCTAssertEqual(try store.dailyTotal(on: date(0)), 0, accuracy: 0.001)
        XCTAssertEqual(try store.exportCSV(), Data("start,end,active_seconds,tracking_mode\n".utf8))
    }

    func testAppUsageAddsUpDetailedSamplesPerAppWithTheirMostUsedWindows() throws {
        let store = try makeStore()
        func sample(_ at: TimeInterval, _ app: String, _ title: String?) throws {
            try store.save(segment: ActivitySegment(timestamp: date(at), appName: app, windowTitle: title, browserURL: nil))
        }
        try sample(0, "Ghostty", "build")
        try sample(15, "Ghostty", "build")
        try sample(30, "Ghostty", "logs")
        try sample(45, "Arc", nil)
        try sample(86_400, "Arc", "tomorrow")

        let usage = try store.appUsage(from: date(0), to: date(86_400))

        XCTAssertEqual(usage.map(\.appName), ["Ghostty", "Arc"])
        XCTAssertEqual(usage[0].seconds, 3 * SwiftDataLocalStore.detailedSampleInterval, accuracy: 0.001)
        XCTAssertEqual(usage[0].topWindows, ["build", "logs"])
        XCTAssertEqual(usage[1].seconds, SwiftDataLocalStore.detailedSampleInterval, accuracy: 0.001)
        XCTAssertEqual(usage[1].topWindows, [], "a window from another day is not counted")
    }

    func testAnOngoingSessionCountsNowAndIsUpdatedInPlaceNotDuplicated() throws {
        let store = try makeStore()
        try store.saveOngoing(session: UsageRecord(start: date(0), end: date(15), activeSeconds: 15, mode: .privateMode))
        XCTAssertEqual(try store.dailyTotal(on: date(0)), 15, accuracy: 0.001, "counted before the session ends")

        try store.saveOngoing(session: UsageRecord(start: date(0), end: date(30), activeSeconds: 30, mode: .privateMode))
        XCTAssertEqual(try store.dailyTotal(on: date(0)), 30, accuracy: 0.001, "the same record grows")

        store.finishOngoingSession()
        try store.saveOngoing(session: UsageRecord(start: date(100), end: date(110), activeSeconds: 10, mode: .privateMode))
        XCTAssertEqual(try store.dailyTotal(on: date(0)), 40, accuracy: 0.001, "a new session after finishing is a new record")
    }

    func testFirstDetailedSampleDateIsTheEarliestSample() throws {
        let store = try makeStore()
        XCTAssertNil(try store.firstDetailedSampleDate())

        try store.save(segment: ActivitySegment(timestamp: date(500), appName: "Arc", windowTitle: nil, browserURL: nil))
        try store.save(segment: ActivitySegment(timestamp: date(100), appName: "Arc", windowTitle: nil, browserURL: nil))

        XCTAssertEqual(try store.firstDetailedSampleDate(), date(100))
    }
}
