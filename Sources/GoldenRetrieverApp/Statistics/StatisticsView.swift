import Foundation
import GoldenRetrieverCore
import SwiftUI

public enum StatisticsRange: CaseIterable, Hashable {
    case today
    case lastSevenDays
    case thisMonth

    public var title: String {
        switch self {
        case .today: "今天"
        case .lastSevenDays: "近 7 天"
        case .thisMonth: "本月"
        }
    }
}

public struct StatisticsView: View {
    public let store: any LocalStore
    public let range: StatisticsRange
    private let calendar: Calendar
    @State private var total: TimeInterval = 0
    @State private var loadError: String?

    public init(store: any LocalStore, range: StatisticsRange, calendar: Calendar = .current) {
        self.store = store
        self.range = range
        self.calendar = calendar
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("使用統計 · \(range.title)")
                .font(.headline)
            if let loadError {
                Text(loadError).foregroundStyle(.red)
            } else if total == 0 {
                ContentUnavailableView("還沒有紀錄", systemImage: "leaf", description: Text("小黃金會在本機累積你的使用時間。"))
            } else {
                Text(format(total))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("請記得讓眼睛和身體休息一下。")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 320, alignment: .leading)
        .task { load() }
    }

    private func load() {
        do {
            total = try totalForRange()
        } catch {
            loadError = "讀取統計失敗：\(error.localizedDescription)"
        }
    }

    private func totalForRange() throws -> TimeInterval {
        let today = calendar.startOfDay(for: Date())
        switch range {
        case .today:
            return try store.dailyTotal(on: today)
        case .lastSevenDays:
            return try (0..<7).reduce(0) { total, offset in
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return total }
                return total + (try store.dailyTotal(on: date))
            }
        case .thisMonth:
            let dayRange = calendar.range(of: .day, in: .month, for: today) ?? 1..<2
            return try dayRange.reduce(0) { total, day in
                guard let date = calendar.date(bySetting: .day, value: day, of: today) else { return total }
                return total + (try store.dailyTotal(on: date))
            }
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        return "\(totalMinutes / 60) 小時 \(totalMinutes % 60) 分鐘"
    }
}
