import AppKit
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
    private let isDetailed: Bool
    private let onEnableDetailed: () -> Void
    @State private var range: StatisticsRange
    @State private var total: TimeInterval = 0
    @State private var apps: [AppUsage] = []
    // Totals and per-app samples began on different days, so each part
    // shows 尚無資料 on its own while it has only today's records.
    @State private var totalIsPartial = false
    @State private var listReachesBottom = false
    @State private var appsArePartial = false
    @State private var loadError: String?

    private static let appsShown = 5
    private static let rowHeight: CGFloat = 40

    public init(
        store: any LocalStore,
        range: StatisticsRange,
        calendar: Calendar = .current,
        isDetailed: Bool = true,
        onEnableDetailed: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {}
    ) {
        self.store = store
        self._range = State(initialValue: range)
        self.calendar = calendar
        self.onClose = onClose
        self.isDetailed = isDetailed
        self.onEnableDetailed = onEnableDetailed
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BackButton(action: onClose)
                Spacer()
                rangePicker
            }
            .padding(.bottom, 8)
            .padding(.horizontal, PopoverView.blockInset)
            PanelDivider()
            if let loadError {
                Text(loadError).font(.system(size: 12)).foregroundStyle(PanelStyle.red)
                    .padding(.top, 8)
                    .padding(.horizontal, PopoverView.blockInset)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("總共").font(.system(size: 12))
                    Spacer()
                    Text(totalIsPartial ? "尚無資料" : Self.format(total))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(totalIsPartial ? PanelStyle.muted : PanelStyle.text)
                        .monospacedDigit()
                }
                .padding(.vertical, 7)
                .padding(.horizontal, PopoverView.blockInset)
                PanelDivider()
                appList
                    .padding(.top, 8)
                    .padding(.horizontal, PopoverView.blockInset)
            }
        }
        .foregroundStyle(PanelStyle.text)
        // Same edges as the main panel: dividers span the width, text is inset.
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: PopoverLayout.size.width, height: PopoverLayout.size.height, alignment: .topLeading)
        .task(id: "\(range)-\(isDetailed)") { load() }
    }

    @ViewBuilder
    private var appList: some View {
        if !isDetailed {
            VStack(spacing: 10) {
                Text("Private 模式只記使用時間")
                    .font(.system(size: 12))
                    .foregroundStyle(PanelStyle.muted)
                Button(action: onEnableDetailed) {
                    Text("切換成 Detailed，看各 app 用了多久")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(PanelStyle.orange, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if appsArePartial || apps.isEmpty {
            Text("尚無資料")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(PanelStyle.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let longest = apps.first?.seconds ?? 1
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
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
                            // One window each, so more apps fit before scrolling.
                            ForEach(app.topWindows.prefix(1), id: \.self) { title in
                                Text(title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(PanelStyle.muted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .frame(height: Self.rowHeight, alignment: .top)
                    }
                }
                // Room for the overlay scroller so it never covers the times.
                .padding(.trailing, 12)
                .background(ScrollBottomObserver { listReachesBottom = $0 })
            }
            // Three and a half rows: the half row plus the fade says there is more.
            .frame(height: Self.rowHeight * 3.5)
            .scrollIndicators(.visible)
            // A fade at the bottom shows there is more to scroll to, and goes
            // away once the last row is in view so it stays readable.
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [PanelStyle.panel.opacity(0), PanelStyle.panel.opacity(0.85), PanelStyle.panel],
                    startPoint: .top,
                    endPoint: .bottom
                )
                    .frame(height: Self.rowHeight * 0.85)
                    .opacity(listReachesBottom ? 0 : 1)
                    .animation(.easeOut(duration: 0.15), value: listReachesBottom)
                    .allowsHitTesting(false)
            }
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 2) {
            ForEach(StatisticsRange.allCases, id: \.self) { option in
                let isOn = option == range
                Button { range = option } label: {
                    Text(option.title)
                        .font(.system(size: 10, weight: isOn ? .heavy : .regular))
                        .foregroundStyle(isOn ? Color.white : PanelStyle.chipText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
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
            totalIsPartial = try isPartial(since: store.firstSessionDate(), today: today)
            appsArePartial = try isPartial(since: store.firstDetailedSampleDate(), today: today)
            loadError = nil
        } catch {
            loadError = "讀取統計失敗：\(error.localizedDescription)"
        }
    }

    /// 近 7 天 and 本月 show whatever days exist once there is more than one;
    /// with only today's records they would just repeat 今天.
    private func isPartial(since first: Date?, today: Date) -> Bool {
        guard range != .today else { return false }
        guard let first else { return true }
        return calendar.startOfDay(for: first) >= today
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

/// Reports whether the enclosing scroll view shows the end of its content.
/// A GeometryReader preference in the list did not update while scrolling on
/// macOS 26 (v1.0.2 kept the fade at the bottom), and SwiftUI's own scroll
/// geometry needs macOS 15, so this reads the AppKit scroll view directly.
private struct ScrollBottomObserver: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.onChange = onChange
        // The scroll view is found once this view is in the window.
        DispatchQueue.main.async { context.coordinator.attach(to: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.report()
    }

    final class Coordinator: NSObject {
        var onChange: (Bool) -> Void = { _ in }
        private weak var scrollView: NSScrollView?
        private var lastReported: Bool?

        func attach(to view: NSView) {
            guard let scrollView = view.enclosingScrollView else { return }
            self.scrollView = scrollView
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(changed), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
            if let document = scrollView.documentView {
                document.postsFrameChangedNotifications = true
                NotificationCenter.default.addObserver(self, selector: #selector(changed), name: NSView.frameDidChangeNotification, object: document)
            }
            report()
        }

        @objc private func changed() { report() }

        func report() {
            guard let scrollView, let document = scrollView.documentView else { return }
            let visible = scrollView.contentView.bounds
            let atBottom = document.isFlipped
                ? visible.maxY >= document.frame.height - 1
                : visible.minY <= 1
            guard atBottom != lastReported else { return }
            lastReported = atBottom
            // Never change SwiftUI state in the middle of a view update.
            DispatchQueue.main.async { [onChange] in onChange(atBottom) }
        }

        deinit { NotificationCenter.default.removeObserver(self) }
    }
}
