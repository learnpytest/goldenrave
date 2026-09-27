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
/// sizes made the popover shrink after returning from settings. The puppy
/// animates in the menu bar, so the panel holds no animation and no blank area.
enum PopoverLayout {
    static let size = CGSize(width: 320, height: 260)
}

/// Show pet / Hide pet: whether 小金金 floats onto the desktop at break time.
enum PetVisibility: CaseIterable {
    case hide
    case show

    init(showsPet: Bool) {
        self = showsPet ? .show : .hide
    }

    var title: String {
        switch self {
        case .hide: "Hide pet"
        case .show: "Show pet"
        }
    }
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
    public let invitationTextAt: ((Date) -> String?)?
    public let showsPet: Bool
    public var onStart: (BreakActivity) -> Void
    public var onPauseReminders: () -> Void
    public var onResumeReminders: () -> Void
    public var onEndBreak: () -> Void
    public var onOpenSettings: () -> Void
    public var onSetShowsPet: (Bool) -> Void

    public init(
        snapshot: UsageSnapshot,
        dogState: DogState,
        nextBreak: Date? = nil,
        breakEndsAt: Date? = nil,
        breakActivity: BreakActivity? = nil,
        remindersPaused: Bool = false,
        invitationText: String? = nil,
        invitationTextAt: ((Date) -> String?)? = nil,
        showsPet: Bool = true,
        onStart: @escaping (BreakActivity) -> Void = { _ in },
        onPauseReminders: @escaping () -> Void = {},
        onResumeReminders: @escaping () -> Void = {},
        onEndBreak: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onSetShowsPet: @escaping (Bool) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.dogState = dogState
        self.nextBreak = nextBreak
        self.breakEndsAt = breakEndsAt
        self.breakActivity = breakActivity
        self.remindersPaused = remindersPaused
        self.invitationText = invitationText
        self.invitationTextAt = invitationTextAt
        self.showsPet = showsPet
        self.onStart = onStart
        self.onPauseReminders = onPauseReminders
        self.onResumeReminders = onResumeReminders
        self.onEndBreak = onEndBreak
        self.onOpenSettings = onOpenSettings
        self.onSetShowsPet = onSetShowsPet
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("小金金陪伴中")
                    .font(.system(size: 20, weight: .heavy))
                HStack {
                    Spacer()
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17))
                    }
                    .buttonStyle(.borderless)
                    .help("設定")
                    .accessibilityLabel("設定")
                }
            }
            .frame(minHeight: 30)
            // The invitation line rotates every 45s while the popover stays open.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(stateDescription(at: context.date))
            }
                .font(.system(size: 14))
                .foregroundStyle(PanelStyle.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.bottom, 14)
            CreamBlock {
                VStack(spacing: 10) {
                    statusRow("這次連續使用", Self.format(snapshot.currentSession))
                    breakMetric
                }
            }
            petVisibility
                .padding(.top, 12)
            HStack(spacing: 8) {
                ForEach(controls, id: \.title) { control in
                    controlButton(control)
                }
            }
            .padding(.top, 14)
        }
        .foregroundStyle(PanelStyle.text)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(width: PopoverLayout.size.width, height: PopoverLayout.size.height, alignment: .top)
    }

    private var petVisibility: some View {
        HStack {
            Text("休息時顯示小金金")
                .font(.system(size: 12))
            Spacer()
            HStack(spacing: 2) {
                ForEach(PetVisibility.allCases, id: \.self) { option in
                    let isOn = PetVisibility(showsPet: showsPet) == option
                    Button { onSetShowsPet(option == .show) } label: {
                        Text(option.title)
                            .font(.system(size: 11, weight: isOn ? .heavy : .regular))
                            .foregroundStyle(isOn ? Color.white : PanelStyle.chipText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(isOn ? PanelStyle.orange : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(PanelStyle.chip, in: Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(PanelStyle.cream, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    @ViewBuilder
    private func controlButton(_ control: PopoverControl) -> some View {
        if let icon = control.systemImage {
            Spacer(minLength: 0)
            Button { perform(control) } label: {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(control == .pauseReminders ? PanelStyle.red : PanelStyle.green)
            }
            .buttonStyle(.plain)
            .help(control.title)
            .accessibilityLabel(control.title)
        } else {
            let isPrimary = control == .start(.play)
            Button { perform(control) } label: {
                Text(control.title)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(isPrimary ? Color.white : PanelStyle.chipText)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(isPrimary ? PanelStyle.orange : PanelStyle.chip, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    static func controls(isOnBreak: Bool, remindersPaused: Bool, hasScheduledBreak: Bool) -> [PopoverControl] {
        if isOnBreak {
            return [.endBreak]
        }
        let activities = BreakActivity.allCases.map(PopoverControl.start)
        return activities + [remindersPaused ? .resumeReminders : .pauseReminders]
    }

    /// While the puppy is inviting, the row says the break is here and keeps
    /// the time it was planned for, rather than "現在".
    static func breakRow(nextBreak: Date?, isInviting: Bool, now: Date) -> (title: String, value: String) {
        if isInviting, let nextBreak {
            return ("喘口氣時間到了", timeString(nextBreak))
        }
        return ("下次喘口氣", nextBreakText(nextBreak, now: now))
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
            statusRow((breakActivity ?? .rest).ongoingTitle, "還剩 \(minutes) 分鐘（\(Self.timeString(breakEndsAt)) 結束）")
        } else if remindersPaused {
            statusRow("下次喘口氣", "已暫停")
        } else if invitationText != nil {
            let row = Self.breakRow(nextBreak: nextBreak, isInviting: true, now: Date())
            HStack(spacing: 6) {
                Image(systemName: "pawprint.fill")
                Text(row.title).fontWeight(.semibold)
                Spacer()
                Text(row.value).font(.system(size: 16, weight: .bold)).monospacedDigit()
            }
            .font(.system(size: 14))
            .foregroundStyle(PanelStyle.orange)
        } else {
            let row = Self.breakRow(nextBreak: nextBreak, isInviting: false, now: Date())
            statusRow(row.title, row.value)
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

    private func stateDescription(at date: Date) -> String {
        switch dogState {
        case .idle: "等你回來"
        case .walk: "慢慢走，先熱身"
        case .run: "跑起來了！"
        case .pounce: invitationTextAt?(date) ?? invitationText ?? BreakInvitation.lines[0].text
        case .rest:
            switch breakActivity ?? .rest {
            case .rest: "正在休息"
            case .play: "一起玩！"
            case .walk: "散步中"
            }
        case .relaxing: "自己玩，不吵你"
        }
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d 分 %02d 秒", total / 60, total % 60)
    }

    static func timeString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
