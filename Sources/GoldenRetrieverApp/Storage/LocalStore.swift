import Foundation
import GoldenRetrieverCore
import SwiftData

public protocol LocalStore {
    func save(session: UsageRecord) throws
    /// Saves the session still in progress, updating the same record on each
    /// call until `finishOngoingSession`, so quitting loses at most one tick.
    func saveOngoing(session: UsageRecord) throws
    func finishOngoingSession()
    func save(breakEvent: BreakEventRecord) throws
    func dailyTotal(on date: Date) throws -> TimeInterval
    /// Detailed mode only: time per app in [start, end), most used first.
    func appUsage(from start: Date, to end: Date) throws -> [AppUsage]
    /// When per-app recording began, so a longer range can say it is partial.
    func firstDetailedSampleDate() throws -> Date?
    /// When usage-time recording began, so a longer total can say it is partial.
    func firstSessionDate() throws -> Date?
    func exportCSV() throws -> Data
    func deleteAll() throws
}

public struct AppUsage: Equatable, Sendable {
    public let appName: String
    public let seconds: TimeInterval
    /// The app's most-sampled window titles, at most two.
    public let topWindows: [String]
}

public enum LocalStoreError: Error, Equatable {
    case invalidRecord
}

public final class SwiftDataLocalStore: LocalStore, DetailedActivityStore {
    private let container: ModelContainer
    private let context: ModelContext
    private let calendar: Calendar
    private var ongoing: UsageSessionModel?

    public init(container: ModelContainer, calendar: Calendar = .current) {
        self.container = container
        self.context = ModelContext(container)
        self.calendar = calendar
    }

    public static func makeDefault(calendar: Calendar = .current) throws -> SwiftDataLocalStore {
        let url = try StoreLocation.prepare(applicationSupport: StoreLocation.applicationSupport)
        let configuration = ModelConfiguration(url: url)
        let container = try ModelContainer(
            for: UsageSessionModel.self,
            BreakEventModel.self,
            DetailedActivityModel.self,
            configurations: configuration
        )
        return SwiftDataLocalStore(container: container, calendar: calendar)
    }

    public func save(session: UsageRecord) throws {
        guard session.end >= session.start, session.activeSeconds >= 0 else {
            throw LocalStoreError.invalidRecord
        }
        context.insert(UsageSessionModel(record: session))
        try context.save()
    }

    public func saveOngoing(session: UsageRecord) throws {
        guard session.end >= session.start, session.activeSeconds >= 0 else {
            throw LocalStoreError.invalidRecord
        }
        if let ongoing, ongoing.start == session.start {
            ongoing.end = session.end
            ongoing.activeSeconds = session.activeSeconds
            ongoing.trackingModeRaw = session.mode.rawValue
        } else {
            let model = UsageSessionModel(record: session)
            context.insert(model)
            ongoing = model
        }
        try context.save()
    }

    public func finishOngoingSession() {
        ongoing = nil
    }

    public func save(breakEvent: BreakEventRecord) throws {
        context.insert(BreakEventModel(record: breakEvent))
        try context.save()
    }

    public func save(segment: ActivitySegment) throws {
        context.insert(DetailedActivityModel(segment: segment))
        try context.save()
    }

    /// Detailed mode samples the frontmost app once per `AppRuntime` tick,
    /// so each stored segment stands for that much time.
    public static let detailedSampleInterval: TimeInterval = 15

    public func appUsage(from start: Date, to end: Date) throws -> [AppUsage] {
        let descriptor = FetchDescriptor<DetailedActivityModel>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end }
        )
        let segments = try context.fetch(descriptor)
        return Dictionary(grouping: segments, by: \.appName)
            .map { appName, samples in
                let titleCounts = Dictionary(grouping: samples.compactMap(\.windowTitle).filter { !$0.isEmpty }, by: { $0 })
                    .mapValues(\.count)
                let topWindows = titleCounts
                    .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                    .prefix(2)
                    .map(\.key)
                return AppUsage(
                    appName: appName,
                    seconds: Double(samples.count) * Self.detailedSampleInterval,
                    topWindows: topWindows
                )
            }
            .sorted { $0.seconds != $1.seconds ? $0.seconds > $1.seconds : $0.appName < $1.appName }
    }

    public func firstDetailedSampleDate() throws -> Date? {
        var descriptor = FetchDescriptor<DetailedActivityModel>(sortBy: [SortDescriptor(\.timestamp)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.timestamp
    }

    public func firstSessionDate() throws -> Date? {
        var descriptor = FetchDescriptor<UsageSessionModel>(sortBy: [SortDescriptor(\.start)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.start
    }

    public func dailyTotal(on date: Date) throws -> TimeInterval {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return 0
        }
        let sessions = try context.fetch(FetchDescriptor<UsageSessionModel>())
        return sessions.reduce(0) { total, model in
            total + activeSeconds(model.record(), overlapping: dayStart..<dayEnd)
        }
    }

    public func exportCSV() throws -> Data {
        let sessions = try context.fetch(FetchDescriptor<UsageSessionModel>())
            .map { $0.record() }
            .sorted { $0.start < $1.start }
        let detailedSegments = try context.fetch(FetchDescriptor<DetailedActivityModel>())
            .sorted { $0.timestamp < $1.timestamp }
        let hasDetails = sessions.contains { $0.mode == .detailed || $0.appName != nil || $0.windowTitle != nil || $0.browserURL != nil } || !detailedSegments.isEmpty
        var lines = [hasDetails
            ? "start,end,active_seconds,tracking_mode,app_name,window_title,browser_url"
            : "start,end,active_seconds,tracking_mode"]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for session in sessions {
            var fields = [
                formatter.string(from: session.start),
                formatter.string(from: session.end),
                String(session.activeSeconds),
                session.mode.rawValue
            ]
            if hasDetails {
                fields += [session.appName, session.windowTitle, session.browserURL?.absoluteString]
                    .map { escapeCSV($0 ?? "") }
            }
            lines.append(fields.map(escapeCSV).joined(separator: ","))
        }
        for segment in detailedSegments {
            let fields = [
                formatter.string(from: segment.timestamp),
                formatter.string(from: segment.timestamp),
                "0",
                TrackingMode.detailed.rawValue,
                segment.appName,
                segment.windowTitle ?? "",
                segment.browserURLString ?? ""
            ]
            lines.append(fields.map(escapeCSV).joined(separator: ","))
        }
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    public func deleteAll() throws {
        ongoing = nil
        for model in try context.fetch(FetchDescriptor<UsageSessionModel>()) {
            context.delete(model)
        }
        for model in try context.fetch(FetchDescriptor<BreakEventModel>()) {
            context.delete(model)
        }
        for model in try context.fetch(FetchDescriptor<DetailedActivityModel>()) {
            context.delete(model)
        }
        try context.save()
    }

    private func activeSeconds(_ record: UsageRecord, overlapping range: Range<Date>) -> TimeInterval {
        let overlapStart = max(record.start, range.lowerBound)
        let overlapEnd = min(record.end, range.upperBound)
        guard overlapEnd > overlapStart else { return 0 }
        let duration = record.end.timeIntervalSince(record.start)
        guard duration > 0 else { return record.activeSeconds }
        let fraction = overlapEnd.timeIntervalSince(overlapStart) / duration
        return record.activeSeconds * fraction
    }

    private func escapeCSV(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
