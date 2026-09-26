import GoldenRetrieverCore
import SwiftUI

enum PopoverControl: Equatable {
    case startBreak
    case postpone
    case pauseReminders
    case resumeReminders
    case endBreak

    var title: String {
        switch self {
        case .startBreak: "開始休息"
        case .postpone: "休息延後 10 分鐘"
        case .pauseReminders: "暫停休息提醒"
        case .resumeReminders: "恢復休息提醒"
        case .endBreak: "提早結束休息"
        }
    }
}

public struct PopoverView: View {
    public let snapshot: UsageSnapshot
    public let dogState: DogState
    public let nextBreak: Date?
    public let breakEndsAt: Date?
    public let remindersPaused: Bool
    public let animationAt: ((Date) -> DogAnimation)?
    public var onStartBreak: () -> Void
    public var onPostpone: () -> Void
    public var onPauseReminders: () -> Void
    public var onResumeReminders: () -> Void
    public var onEndBreak: () -> Void
    public var onOpenStatistics: () -> Void
    public var onOpenSettings: () -> Void

    public init(
        snapshot: UsageSnapshot,
        dogState: DogState,
        nextBreak: Date? = nil,
        breakEndsAt: Date? = nil,
        remindersPaused: Bool = false,
        animationAt: ((Date) -> DogAnimation)? = nil,
        onStartBreak: @escaping () -> Void = {},
        onPostpone: @escaping () -> Void = {},
        onPauseReminders: @escaping () -> Void = {},
        onResumeReminders: @escaping () -> Void = {},
        onEndBreak: @escaping () -> Void = {},
        onOpenStatistics: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.dogState = dogState
        self.nextBreak = nextBreak
        self.breakEndsAt = breakEndsAt
        self.remindersPaused = remindersPaused
        self.animationAt = animationAt
        self.onStartBreak = onStartBreak
        self.onPostpone = onPostpone
        self.onPauseReminders = onPauseReminders
        self.onResumeReminders = onResumeReminders
        self.onEndBreak = onEndBreak
        self.onOpenStatistics = onOpenStatistics
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                DogAnimationView(animationAt: animationAt ?? { [dogState] date in
                    DogAnimationDirector().animation(for: dogState, at: date)
                })
                    .frame(width: 90, height: 90)
                VStack(alignment: .leading) {
                    Text("小黃金陪伴中")
                        .font(.headline)
                    Text(stateDescription)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            metric("這次連續使用", Self.format(snapshot.currentSession))
            metric("今天累積使用", Self.format(snapshot.todayTotal))
            breakMetric
            HStack {
                ForEach(controls, id: \.title) { control in
                    Button(control.title) { perform(control) }
                }
            }
            HStack {
                Button("查看統計", action: onOpenStatistics)
                Button("設定", action: onOpenSettings)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    static func controls(isOnBreak: Bool, remindersPaused: Bool, hasScheduledBreak: Bool) -> [PopoverControl] {
        if isOnBreak {
            return [.endBreak]
        }
        if remindersPaused {
            return [.startBreak, .resumeReminders]
        }
        return hasScheduledBreak ? [.startBreak, .postpone, .pauseReminders] : [.startBreak, .pauseReminders]
    }

    static func remainingBreakMinutes(until endsAt: Date, now: Date) -> Int {
        max(0, Int((endsAt.timeIntervalSince(now) / 60).rounded(.up)))
    }

    private var controls: [PopoverControl] {
        Self.controls(
            isOnBreak: breakEndsAt != nil,
            remindersPaused: remindersPaused,
            hasScheduledBreak: nextBreak != nil
        )
    }

    @ViewBuilder
    private var breakMetric: some View {
        if let breakEndsAt {
            let minutes = Self.remainingBreakMinutes(until: breakEndsAt, now: Date())
            metric("休息中", "還剩 \(minutes) 分鐘（\(Self.timeString(breakEndsAt)) 結束）")
        } else if remindersPaused {
            metric("下次休息", "休息提醒已暫停")
        } else {
            metric("下次休息", nextBreak.map(Self.timeString) ?? "尚未排程")
        }
    }

    private func perform(_ control: PopoverControl) {
        switch control {
        case .startBreak: onStartBreak()
        case .postpone: onPostpone()
        case .pauseReminders: onPauseReminders()
        case .resumeReminders: onResumeReminders()
        case .endBreak: onEndBreak()
        }
    }

    private var stateDescription: String {
        switch dogState {
        case .idle: "等你回來"
        case .walk: "慢慢走，先熱身"
        case .run: "跑起來了！"
        case .pounce: "該休息囉！"
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
