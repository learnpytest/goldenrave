import Foundation

public struct ActivityEngine: Sendable {
    private let calendar: Calendar
    private var activeSessionStart: Date?
    private var lastActiveSample: Date?
    private var dailyTotals: [Date: TimeInterval]

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.activeSessionStart = nil
        self.lastActiveSample = nil
        self.dailyTotals = [:]
    }

    public mutating func ingest(_ sample: ActivitySample) -> UsageSnapshot {
        switch sample.kind {
        case .active:
            if let previousActive = lastActiveSample {
                addActiveInterval(from: previousActive, to: sample.timestamp)
            } else {
                activeSessionStart = sample.timestamp
            }
            if activeSessionStart == nil {
                activeSessionStart = sample.timestamp
            }
            lastActiveSample = sample.timestamp
        case .idle:
            if let previousActive = lastActiveSample {
                addActiveInterval(from: previousActive, to: sample.timestamp)
            }
            activeSessionStart = nil
            lastActiveSample = nil
        }

        let total = dailyTotals[dayStart(for: sample.timestamp), default: 0]
        let currentSession: TimeInterval
        if let activeSessionStart, sample.kind == .active {
            currentSession = max(0, sample.timestamp.timeIntervalSince(activeSessionStart))
        } else {
            currentSession = 0
        }

        return UsageSnapshot(
            isActive: sample.kind == .active,
            currentSession: currentSession,
            todayTotal: total
        )
    }

    public mutating func reset() {
        activeSessionStart = nil
        lastActiveSample = nil
    }

    public func total(on date: Date) -> TimeInterval {
        dailyTotals[dayStart(for: date), default: 0]
    }

    private func dayStart(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private mutating func addActiveInterval(from start: Date, to end: Date) {
        guard end > start else { return }

        var cursor = start
        while cursor < end {
            let day = dayStart(for: cursor)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return }
            let segmentEnd = min(end, nextDay)
            dailyTotals[day, default: 0] += segmentEnd.timeIntervalSince(cursor)
            cursor = segmentEnd
        }
    }
}
