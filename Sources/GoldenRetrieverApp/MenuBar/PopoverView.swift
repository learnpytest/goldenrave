import GoldenRetrieverCore
import SwiftUI

enum PopoverControl: Equatable {
    case start(BreakActivity)
    case pauseReminders
    case resumeReminders
    case endBreak

    var title: String {
        switch self {
        case .start(.rest): "休息"
        case .start(.play): "陪玩"
        case .start(.walk): "散步"
        case .pauseReminders: "暫停"
        case .resumeReminders: "恢復"
        case .endBreak: "提早結束"
        }
    }
}

extension PopoverControl {
    /// Pause and resume are media-style icons; the activity choices stay text.
    var systemImage: String? {
        switch self {
        case .pauseReminders: "pause.circle.fill"
        case .resumeReminders: "play.circle.fill"
        default: nil
        }
    }

    var iconColor: Color {
        self == .pauseReminders ? .red : .green
    }
}

/// Every popover screen shares one size; swapping screens of different
/// sizes made the popover shrink after returning from settings.
enum PopoverLayout {
    static let size = CGSize(width: 320, height: 310)
}

extension BreakActivity {
    var ongoingTitle: String {
        switch self {
        case .rest: "休息中"
        case .play: "陪玩中"
        case .walk: "散步中"
        }
    }
}

public struct PopoverView: View {
    public let snapshot: UsageSnapshot
    public let dogState: DogState
    public let nextBreak: Date?
    public let breakEndsAt: Date?
    public let breakActivity: BreakActivity?
    public let remindersPaused: Bool
    public let invitationText: String?
    public let playbackAt: ((Date) -> DogAnimationPlayback)?
    public var onStart: (BreakActivity) -> Void
    public var onPauseReminders: () -> Void
    public var onResumeReminders: () -> Void
    public var onEndBreak: () -> Void
    public var onOpenSettings: () -> Void

    public init(
        snapshot: UsageSnapshot,
        dogState: DogState,
        nextBreak: Date? = nil,
        breakEndsAt: Date? = nil,
        breakActivity: BreakActivity? = nil,
        remindersPaused: Bool = false,
        invitationText: String? = nil,
        playbackAt: ((Date) -> DogAnimationPlayback)? = nil,
        onStart: @escaping (BreakActivity) -> Void = { _ in },
        onPauseReminders: @escaping () -> Void = {},
        onResumeReminders: @escaping () -> Void = {},
        onEndBreak: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.dogState = dogState
        self.nextBreak = nextBreak
        self.breakEndsAt = breakEndsAt
        self.breakActivity = breakActivity
        self.remindersPaused = remindersPaused
        self.invitationText = invitationText
        self.playbackAt = playbackAt
        self.onStart = onStart
        self.onPauseReminders = onPauseReminders
        self.onResumeReminders = onResumeReminders
        self.onEndBreak = onEndBreak
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("小金金陪伴中")
                    .font(.headline)
                Text(stateDescription)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .help("設定")
                .accessibilityLabel("設定")
            }
            DogAnimationView(playbackAt: playbackAt ?? { [dogState] date in
                DogAnimationDirector().playback(for: dogState, at: date)
            })
                .frame(width: DogAnimationPlayer.popoverSide, height: DogAnimationPlayer.popoverSide)
                .frame(maxWidth: .infinity)
            VStack(spacing: 6) {
                metric("這次連續使用", Self.format(snapshot.currentSession))
                breakMetric
            }
            HStack(spacing: 8) {
                ForEach(controls, id: \.title) { control in
                    controlButton(control)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(width: PopoverLayout.size.width, height: PopoverLayout.size.height, alignment: .top)
    }

    @ViewBuilder
    private func controlButton(_ control: PopoverControl) -> some View {
        if let icon = control.systemImage {
            Button { perform(control) } label: {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(control.iconColor)
            }
            .buttonStyle(.borderless)
            .help(control.title)
            .accessibilityLabel(control.title)
        } else {
            Button(control.title) { perform(control) }
        }
    }

    static func controls(isOnBreak: Bool, remindersPaused: Bool, hasScheduledBreak: Bool) -> [PopoverControl] {
        if isOnBreak {
            return [.endBreak]
        }
        let activities = BreakActivity.allCases.map(PopoverControl.start)
        return activities + [remindersPaused ? .resumeReminders : .pauseReminders]
    }

    /// A reminder that is already due reads "現在", never a time in the past.
    static func nextBreakText(_ nextBreak: Date?, now: Date) -> String {
        guard let nextBreak else { return "尚未排程" }
        return nextBreak <= now ? "現在" : timeString(nextBreak)
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
            metric((breakActivity ?? .rest).ongoingTitle, "還剩 \(minutes) 分鐘（\(Self.timeString(breakEndsAt)) 結束）")
        } else if remindersPaused {
            metric("喘口氣", "已暫停")
        } else {
            metric("喘口氣", Self.nextBreakText(nextBreak, now: Date()))
        }
    }

    private func perform(_ control: PopoverControl) {
        switch control {
        case .start(let activity): onStart(activity)
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
        case .pounce: invitationText ?? BreakInvitation.lines[0].text
        case .rest:
            switch breakActivity ?? .rest {
            case .rest: "正在休息"
            case .play: "一起玩！"
            case .walk: "散步中"
            }
        case .relaxing: "自己玩，不吵你"
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

    static func timeString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
