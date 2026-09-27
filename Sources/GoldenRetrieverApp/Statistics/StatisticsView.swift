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
    private let calendar: Calendar
    private let onClose: () -> Void
    @State private var range: StatisticsRange
    @State private var total: TimeInterval = 0
    @State private var apps: [AppUsage] = []
    @State private var loadError: String?

    private static let appsShown = 5

    public init(
        store: any LocalStore,
        range: StatisticsRange,
        calendar: Calendar = .current,
        onClose: @escaping () -> Void = {}
    ) {
        self.store = store
        self._range = State(initialValue: range)
        self.calendar = calendar
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PanelStyle.chipText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
                Text("使用統計").font(.system(size: 17, weight: .heavy))
                Spacer()
                rangePicker
            }
            if let loadError {
                Text(loadError).font(.system(size: 12)).foregroundStyle(PanelStyle.red)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("總共").font(.system(size: 13)).foregroundStyle(PanelStyle.muted)
                    Text(Self.format(total)).font(.system(size: 22, weight: .heavy)).monospacedDigit()
                }
                CreamBlock {
                    appList
                }
            }
        }
        .foregroundStyle(PanelStyle.text)
        .padding(16)
        .frame(width: PopoverLayout.size.width, height: PopoverLayout.size.height, alignment: .topLeading)
        .task(id: range) { load() }
    }

    @ViewBuilder
    private var appList: some View {
        if apps.isEmpty {
            Text("切到 Detailed 模式後，這裡會列出各個 app 用了多久。")
                .font(.system(size: 12))
                .foregroundStyle(PanelStyle.muted)
                .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            let longest = apps.first?.seconds ?? 1
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(apps.prefix(Self.appsShown), id: \.appName) { app in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(app.appName)
                                    .font(.system(size: 13, weight: .bold))
                                    .lineLimit(1)
                                    .frame(width: 70, alignment: .leading)
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(PanelStyle.orange.opacity(0.75))
                                        .frame(width: max(4, proxy.size.width * app.seconds / longest))
                                }
                                .frame(height: 8)
                                Text(Self.formatShort(app.seconds))
                                    .font(.system(size: 12))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .fixedSize()
                                    .frame(minWidth: 84, alignment: .trailing)
                            }
                            ForEach(app.topWindows, id: \.self) { title in
                                Text(title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(PanelStyle.muted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }
                // Room for the overlay scroller so it never covers the times.
                .padding(.trailing, 12)
            }
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 2) {
            ForEach(StatisticsRange.allCases, id: \.self) { option in
                let isOn = option == range
                Button { range = option } label: {
                    Text(option.title)
                        .font(.system(size: 11, weight: isOn ? .heavy : .regular))
                        .foregroundStyle(isOn ? Color.white : PanelStyle.chipText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(isOn ? PanelStyle.orange : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(PanelStyle.chip, in: Capsule())
    }

    private func load() {
        do {
            let today = calendar.startOfDay(for: Date())
            let start = rangeStart(today: today)
            let end = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
            total = try totalForRange(from: start, today: today)
            apps = try store.appUsage(from: start, to: end)
            loadError = nil
        } catch {
            loadError = "讀取統計失敗：\(error.localizedDescription)"
        }
    }

    private func rangeStart(today: Date) -> Date {
        switch range {
        case .today:
            return today
        case .lastSevenDays:
            return calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: today)?.start ?? today
        }
    }

    private func totalForRange(from start: Date, today: Date) throws -> TimeInterval {
        var total: TimeInterval = 0
        var day = start
        while day <= today {
            total += try store.dailyTotal(on: day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return total
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        return "\(totalMinutes / 60) 小時 \(totalMinutes % 60) 分鐘"
    }

    private static func formatShort(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        return totalMinutes >= 60 ? "\(totalMinutes / 60) 小時 \(totalMinutes % 60) 分" : "\(totalMinutes) 分"
    }
}
