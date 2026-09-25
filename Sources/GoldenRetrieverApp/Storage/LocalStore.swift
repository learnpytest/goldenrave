import Foundation
import GoldenRetrieverCore
import SwiftData

public protocol LocalStore {
    func save(session: UsageRecord) throws
    func save(breakEvent: BreakEventRecord) throws
    func dailyTotal(on date: Date) throws -> TimeInterval
    func exportCSV() throws -> Data
    func deleteAll() throws
}

public enum LocalStoreError: Error, Equatable {
    case invalidRecord
}

public final class SwiftDataLocalStore: LocalStore {
    private let container: ModelContainer
    private let context: ModelContext
    private let calendar: Calendar

    public init(container: ModelContainer, calendar: Calendar = .current) {
        self.container = container
        self.context = ModelContext(container)
        self.calendar = calendar
    }

    public static func makeDefault(calendar: Calendar = .current) throws -> SwiftDataLocalStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        let container = try ModelContainer(
            for: UsageSessionModel.self,
            BreakEventModel.self,
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

    public func save(breakEvent: BreakEventRecord) throws {
        context.insert(BreakEventModel(record: breakEvent))
        try context.save()
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
        let hasDetails = sessions.contains { $0.mode == .detailed || $0.appName != nil || $0.windowTitle != nil || $0.browserURL != nil }
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
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    public func deleteAll() throws {
        for model in try context.fetch(FetchDescriptor<UsageSessionModel>()) {
            context.delete(model)
        }
        for model in try context.fetch(FetchDescriptor<BreakEventModel>()) {
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
