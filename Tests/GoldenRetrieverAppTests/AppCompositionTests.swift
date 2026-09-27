import Foundation
import XCTest
@testable import GoldenRetrieverApp
@testable import GoldenRetrieverCore

final class AppCompositionTests: XCTestCase {
    private final class FakeStore: LocalStore, DetailedActivityStore {
        var sessions: [UsageRecord] = []
        var segments: [ActivitySegment] = []

        func save(session: UsageRecord) throws { sessions.append(session) }
        private var ongoingIndex: Int?
        func saveOngoing(session: UsageRecord) throws {
            if let ongoingIndex { sessions[ongoingIndex] = session } else { ongoingIndex = sessions.count; sessions.append(session) }
        }
        func finishOngoingSession() { ongoingIndex = nil }
        func save(breakEvent: BreakEventRecord) throws {}
        func appUsage(from start: Date, to end: Date) throws -> [AppUsage] { [] }
        func firstDetailedSampleDate() throws -> Date? { segments.map(\.timestamp).min() }
        func dailyTotal(on date: Date) throws -> TimeInterval {
            let start = Calendar.current.startOfDay(for: date)
            guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return 0 }
            return sessions.reduce(0) { total, record in
                let overlap = max(0, min(record.end, end).timeIntervalSince(max(record.start, start)))
                return total + (record.end > record.start ? record.activeSeconds * overlap / record.end.timeIntervalSince(record.start) : record.activeSeconds)
            }
        }
        func exportCSV() throws -> Data { Data() }
        func deleteAll() throws { sessions.removeAll(); segments.removeAll() }
        func save(segment: ActivitySegment) throws { segments.append(segment) }
    }

    private struct FakePermission: PermissionCoordinator {
        var canReadDetailedActivity: Bool { true }
        func requestDetailedActivityPermission() {}
    }

    private struct FakeReader: DetailedActivityReader {
        func read() -> ActivitySegment? { nil }
    }

    private struct FakeNotifications: NotificationPresenter {
        func requestAuthorization() async throws {}
        func presentBreakWarning(secondsRemaining: TimeInterval) {}
        func presentBreakDue() {}
    }

    private func dependencies(store: FakeStore) -> AppDependencies {
        let controller = TrackingModeController(
            reader: FakeReader(),
            permission: FakePermission(),
            store: store
        )
        return AppDependencies(
            activityEngine: ActivityEngine(),
            store: store,
            scheduler: BreakScheduler(),
            trackingController: controller,
            notificationPresenter: FakeNotifications()
        )
    }

    func testAppStartsInPrivateModeWithSharedStoreAndScheduler() {
        let store = FakeStore()
        let dependencies = dependencies(store: store)

        XCTAssertEqual(dependencies.trackingController.mode, .privateMode)
        XCTAssertTrue((dependencies.store as AnyObject) === store)
        XCTAssertEqual(dependencies.scheduler.policy, BreakPolicy())
        XCTAssertEqual(dependencies.scheduler.calendar.identifier, Calendar.current.identifier)
    }

    func testCompletedSessionFeedsSnapshotAndDailyStatisticsStore() throws {
        let store = FakeStore()
        var dependencies = dependencies(store: store)
        let start = Date(timeIntervalSince1970: 0)
        _ = dependencies.activityEngine.ingest(ActivitySample(timestamp: start, kind: .active))
        let snapshot = dependencies.activityEngine.ingest(ActivitySample(timestamp: start.addingTimeInterval(600), kind: .idle))
        try store.save(session: UsageRecord(
            start: start,
            end: start.addingTimeInterval(600),
            activeSeconds: snapshot.todayTotal,
            mode: .privateMode
        ))

        XCTAssertEqual(snapshot.todayTotal, 600, accuracy: 0.001)
        XCTAssertEqual(try store.dailyTotal(on: start), 600, accuracy: 0.001)
    }
}
