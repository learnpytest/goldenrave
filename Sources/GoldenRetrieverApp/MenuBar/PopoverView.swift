import GoldenRetrieverCore
import SwiftUI

public struct PopoverView: View {
    public let snapshot: UsageSnapshot
    public let dogState: DogState
    public let nextBreak: Date?
    public var onStartBreak: () -> Void
    public var onPostpone: () -> Void
    public var onPauseReminders: () -> Void
    public var onOpenStatistics: () -> Void
    public var onOpenSettings: () -> Void

    public init(
        snapshot: UsageSnapshot,
        dogState: DogState,
        nextBreak: Date? = nil,
        onStartBreak: @escaping () -> Void = {},
        onPostpone: @escaping () -> Void = {},
        onPauseReminders: @escaping () -> Void = {},
        onOpenStatistics: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.dogState = dogState
        self.nextBreak = nextBreak
        self.onStartBreak = onStartBreak
        self.onPostpone = onPostpone
        self.onPauseReminders = onPauseReminders
        self.onOpenStatistics = onOpenStatistics
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                DogAnimationView(state: dogState)
                    .frame(width: 90, height: 90)
                VStack(alignment: .leading) {
                    Text("小黃金陪伴中")
                        .font(.headline)
                    Text(stateDescription)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            metric("這次連續使用", format(snapshot.currentSession))
            metric("今天累積使用", format(snapshot.todayTotal))
            metric("下次休息", nextBreak.map(Self.timeString) ?? "尚未排程")
            HStack {
                Button("開始休息", action: onStartBreak)
                Button("延後 10 分鐘", action: onPostpone)
            }
            HStack {
                Button("暫停提醒", action: onPauseReminders)
                Button("查看統計", action: onOpenStatistics)
                Button("設定", action: onOpenSettings)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var stateDescription: String {
        switch dogState {
        case .idle: "等你回來"
        case .walk: "慢慢走，先熱身"
        case .run: "跑起來了！"
        case .play: "玩得很開心"
        case .jump: "快要休息囉"
        case .rest: "正在休息"
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d 分 %02d 秒", total / 60, total % 60)
    }

    private static func timeString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
