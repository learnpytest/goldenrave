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
    static let size = CGSize(width: 320, height: 240)
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
    public var onStart: (BreakActivity) -> Void
    public var onPauseReminders: () -> Void
    public var onResumeReminders: () -> Void
    public var onEndBreak: () -> Void
    public var onOpenSettings: () -> Void
    public var onOpenStatistics: () -> Void
    @State private var showsEarlyBreak = false

    public init(
        snapshot: UsageSnapshot,
        dogState: DogState,
        nextBreak: Date? = nil,
        breakEndsAt: Date? = nil,
        breakActivity: BreakActivity? = nil,
        remindersPaused: Bool = false,
        invitationText: String? = nil,
        invitationTextAt: ((Date) -> String?)? = nil,
        onStart: @escaping (BreakActivity) -> Void = { _ in },
        onPauseReminders: @escaping () -> Void = {},
        onResumeReminders: @escaping () -> Void = {},
        onEndBreak: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onOpenStatistics: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.dogState = dogState
        self.nextBreak = nextBreak
        self.breakEndsAt = breakEndsAt
        self.breakActivity = breakActivity
        self.remindersPaused = remindersPaused
        self.invitationText = invitationText
        self.invitationTextAt = invitationTextAt
        self.onStart = onStart
        self.onPauseReminders = onPauseReminders
        self.onResumeReminders = onResumeReminders
        self.onEndBreak = onEndBreak
        self.onOpenSettings = onOpenSettings
        self.onOpenStatistics = onOpenStatistics
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 6) {
                    Text("小金金陪伴中")
                        .font(.system(size: 20, weight: .heavy))
                    // Pause / resume the reminders from the title they belong to.
                    reminderToggle
                }
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
                VStack(spacing: 8) {
                    statusRow("這次連續使用", Self.format(snapshot.currentSession))
                    breakMetric
                }
            }
            divider
                .padding(.top, 12)
            actionRow
                .frame(minHeight: 22)
                .padding(.vertical, 8)
                .padding(.horizontal, Self.blockInset)
            divider
            statisticsEntry
                .padding(.top, 8)
                .padding(.horizontal, Self.blockInset)
        }
        .onDisappear { showsEarlyBreak = false }
        .foregroundStyle(PanelStyle.text)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(width: PopoverLayout.size.width, height: PopoverLayout.size.height, alignment: .top)
    }

    private var statisticsEntry: some View {
        Button(action: onOpenStatistics) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(PanelStyle.orange)
                Text("使用統計")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("各 app 用了多久")
                    .font(.system(size: 10))
                    .foregroundStyle(PanelStyle.muted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PanelStyle.chipText)
            }
            .foregroundStyle(PanelStyle.text)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func controlButton(_ control: PopoverControl, emphasized: Bool = false) -> some View {
        if let icon = control.systemImage {
            Button { perform(control) } label: {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .frame(width: Self.toggleSide)
                    .foregroundStyle(control == .pauseReminders ? PanelStyle.red : PanelStyle.green)
            }
            .buttonStyle(.plain)
            .help(control.title)
            .accessibilityLabel(control.title)
        } else {
            // No highlighted choice: none of them is running until tapped, and a
            // tap switches to the ongoing-break screen.
            // Outlined pills read as the options of the line before them.
            Button { perform(control) } label: {
                Text(control.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(emphasized ? PanelStyle.orange : PanelStyle.chipText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .overlay(Capsule().stroke(emphasized ? PanelStyle.orange : PanelStyle.line, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    /// 休息／陪玩／散步 exist for a due break; before then they would read as a
    /// nudge, so they wait behind 想提早喘口氣？.
    static func offersActivities(isInviting: Bool, isOnBreak: Bool, userAskedEarly: Bool) -> Bool {
        isInviting || isOnBreak || userAskedEarly
    }

    /// Only the choices the user opened early can be folded away again.
    static func canCancelEarlyBreak(isInviting: Bool, isOnBreak: Bool, userAskedEarly: Bool) -> Bool {
        userAskedEarly && !isInviting && !isOnBreak
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
                Text(row.value).font(.system(size: 14, weight: .bold)).monospacedDigit()
            }
            .font(.system(size: 12))
            .foregroundStyle(PanelStyle.orange)
        } else {
            let row = Self.breakRow(nextBreak: nextBreak, isInviting: false, now: Date())
            statusRow(row.title, row.value)
        }
    }

    /// Matches CreamBlock's inner padding so rows outside it line up with it.
    static let blockInset: CGFloat = 15
    static let toggleSide: CGFloat = 18

    /// Pause / resume.
    @ViewBuilder
    private var reminderToggle: some View {
        ForEach(controls.filter { $0.systemImage != nil }, id: \.title) { control in
            controlButton(control)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(PanelStyle.line.opacity(0.35))
            .frame(height: 1)
    }

    /// The break choices always follow a short line, so it is clear they are
    /// the ways to take the 喘口氣 above.
    @ViewBuilder
    private var actionRow: some View {
        let isInviting = invitationText != nil
        let isOnBreak = breakEndsAt != nil
        HStack(spacing: 6) {
            if Self.offersActivities(isInviting: isInviting, isOnBreak: isOnBreak, userAskedEarly: showsEarlyBreak) {
                Text(isOnBreak ? "喘口氣中" : "怎麼喘口氣？")
                    .font(.system(size: 11, weight: isInviting ? .bold : .regular))
                    .foregroundStyle(isInviting ? PanelStyle.orange : PanelStyle.muted)
                ForEach(controls.filter { $0.systemImage == nil }, id: \.title) { control in
                    controlButton(control, emphasized: isInviting)
                }
                if Self.canCancelEarlyBreak(isInviting: isInviting, isOnBreak: isOnBreak, userAskedEarly: showsEarlyBreak) {
                    Button("取消") { showsEarlyBreak = false }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(PanelStyle.muted)
                        .underline()
                        .padding(.leading, 2)
                }
            } else {
                Button("想提早喘口氣？") { showsEarlyBreak = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(PanelStyle.chipText)
                    .underline()
            }
            Spacer(minLength: 0)
        }
    }

    private func perform(_ control: PopoverControl) {
        switch control {
        case .start(let activity):
            showsEarlyBreak = false
            onStart(activity)
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
        case .pounce:
            FloatingPuppyPlacement.remainder(invitationTextAt?(date) ?? invitationText ?? BreakInvitation.lines[0].text)
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
                .font(.system(size: 12))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
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
