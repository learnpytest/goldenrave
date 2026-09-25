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
}
