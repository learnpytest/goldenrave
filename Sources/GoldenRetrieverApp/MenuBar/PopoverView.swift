import GoldenRetrieverCore
import SwiftUI

enum PopoverControl: Equatable {
    case start(BreakActivity)
    case pauseReminders
    case resumeReminders
    case stopActivity
    case resumeActivity

    var title: String {
        switch self {
        case .start(.rest): "休息"
        case .start(.play): "陪玩"
        case .start(.walk): "散步"
        case .pauseReminders: "暫停"
        case .resumeReminders: "恢復"
        case .stopActivity: "停下"
        case .resumeActivity: "繼續"
        }
    }
}

extension PopoverControl {
    /// Every control is an icon; its title is the tooltip and the
    /// accessibility label.
    var systemImage: String {
        switch self {
        case .start(.rest): "moon.zzz.fill"
        case .start(.play): "tennisball.fill"
        case .start(.walk): "figure.walk"
        case .pauseReminders: "pause.fill"
        case .resumeReminders: "play.fill"
        case .stopActivity: "stop.fill"
        case .resumeActivity: "play.circle.fill"
        }
    }
}

/// Every popover screen shares one size; swapping screens of different
/// sizes made the popover shrink after returning from settings. The puppy
/// animates in the menu bar, so the panel holds no animation and no blank area.
enum PopoverLayout {
    static let size = CGSize(width: 290, height: 240)
    /// The main panel is narrower than statistics and settings, which need the room.
    static let mainWidth: CGFloat = 260
    /// Settings lists one option per row between dividers, so it runs taller.
    static let settingsHeight: CGFloat = 272
    /// The main panel is shorter without the break-choice row, so no blank
    /// row is left between the dividers.
    static func mainHeight(showsActionRow: Bool) -> CGFloat {
        showsActionRow ? 262 : 219
    }
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
    public let breakActivityPaused: Bool
    public let remindersPaused: Bool
    public let invitationText: String?
    public let invitationTextAt: ((Date) -> String?)?
    public var onStart: (BreakActivity) -> Void
    public var onPauseReminders: () -> Void
    public var onResumeReminders: () -> Void
    public var onSetBreakActivityPaused: (Bool) -> Void
    public var onOpenSettings: () -> Void
    public var onOpenStatistics: () -> Void

    public init(
        snapshot: UsageSnapshot,
        dogState: DogState,
        nextBreak: Date? = nil,
        breakEndsAt: Date? = nil,
        breakActivity: BreakActivity? = nil,
        breakActivityPaused: Bool = false,
        remindersPaused: Bool = false,
        invitationText: String? = nil,
        invitationTextAt: ((Date) -> String?)? = nil,
        onStart: @escaping (BreakActivity) -> Void = { _ in },
        onPauseReminders: @escaping () -> Void = {},
        onResumeReminders: @escaping () -> Void = {},
        onSetBreakActivityPaused: @escaping (Bool) -> Void = { _ in },
        onOpenSettings: @escaping () -> Void = {},
        onOpenStatistics: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.dogState = dogState
        self.nextBreak = nextBreak
        self.breakEndsAt = breakEndsAt
        self.breakActivity = breakActivity
        self.breakActivityPaused = breakActivityPaused
        self.remindersPaused = remindersPaused
        self.invitationText = invitationText
        self.invitationTextAt = invitationTextAt
        self.onStart = onStart
        self.onPauseReminders = onPauseReminders
        self.onResumeReminders = onResumeReminders
        self.onSetBreakActivityPaused = onSetBreakActivityPaused
        self.onOpenSettings = onOpenSettings
        self.onOpenStatistics = onOpenStatistics
    }

    public var body: some View {
        VStack(spacing: 0) {
            Text("小金金陪伴中")
                .font(.system(size: 20, weight: .heavy))
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            // The invitation line rotates every 45s while the popover stays open.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(stateDescription(at: context.date))
            }
                .font(.system(size: 14))
                .foregroundStyle(PanelStyle.muted)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.bottom, 14)
            CreamBlock {
                VStack(spacing: 8) {
                    statusRow("連續使用", Self.format(snapshot.currentSession))
                    breakMetric
                }
            }
            divider
                .padding(.top, 12)
            if showsActionRow {
                actionRow
                    .frame(minHeight: 26)
                    .padding(.vertical, 8)
                    .padding(.horizontal, Self.blockInset)
                divider
            }
            footerLink(icon: "chart.bar.fill", title: "使用統計", action: onOpenStatistics)
                .padding(.vertical, 7)
                .padding(.horizontal, Self.blockInset)
            divider
            footerLink(icon: "gearshape.fill", title: "設定", action: onOpenSettings)
                .padding(.top, 7)
                .padding(.horizontal, Self.blockInset)
        }
        .foregroundStyle(PanelStyle.text)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(width: PopoverLayout.mainWidth, height: PopoverLayout.mainHeight(showsActionRow: showsActionRow), alignment: .top)
    }

    private func footerLink(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(PanelStyle.orange)
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PanelStyle.chipText)
            }
            .foregroundStyle(PanelStyle.text)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func controlButton(_ control: PopoverControl, emphasized: Bool = false) -> some View {
        let tint: Color = switch control {
        case .pauseReminders: PanelStyle.red
        case .resumeReminders: PanelStyle.green
        default: emphasized ? PanelStyle.orange : PanelStyle.chipText
        }
        return Button { perform(control) } label: {
            Image(systemName: control.systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(tint.opacity(0.55), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(control.title)
        .accessibilityLabel(control.title)
    }

    /// The controls appear with a due break or during one. Otherwise only
    /// 恢復 stays when reminders are paused, as the way back.
    static func visibleControls(_ controls: [PopoverControl], isInviting: Bool, isOnBreak: Bool = false) -> [PopoverControl] {
        isInviting || isOnBreak ? controls : controls.filter { $0 == .resumeReminders }
    }

    /// During a break the three activities stay so the user can switch, and
    /// ⏹／▶ stops or resumes the current one; nothing ends the break early.
    static func showsActionRow(isInviting: Bool, isOnBreak: Bool, remindersPaused: Bool) -> Bool {
        isInviting || isOnBreak || remindersPaused
    }

    private var showsActionRow: Bool {
        Self.showsActionRow(isInviting: invitationText != nil, isOnBreak: breakEndsAt != nil, remindersPaused: remindersPaused)
    }

    static func controls(isOnBreak: Bool, remindersPaused: Bool, hasScheduledBreak: Bool, activityPaused: Bool = false) -> [PopoverControl] {
        let activities = BreakActivity.allCases.map(PopoverControl.start)
        if isOnBreak {
            return activities + [activityPaused ? .resumeActivity : .stopActivity]
        }
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
            hasScheduledBreak: nextBreak != nil,
            activityPaused: breakActivityPaused
        )
    }

    @ViewBuilder
    private var breakMetric: some View {
        if let breakEndsAt {
            let minutes = Self.remainingBreakMinutes(until: breakEndsAt, now: Date())
            statusRow(breakActivityPaused ? "停下來了" : (breakActivity ?? .rest).ongoingTitle, "還剩 \(minutes) 分鐘（\(Self.timeString(breakEndsAt)) 結束）")
        } else if remindersPaused {
            statusRow("下次喘口氣", "已暫停")
        } else if invitationText != nil {
            let row = Self.breakRow(nextBreak: nextBreak, isInviting: true, now: Date())
            HStack(spacing: 6) {
                Text(row.title).fontWeight(.semibold)
                Spacer()
                Text(row.value).font(.system(size: 13, weight: .bold)).monospacedDigit()
            }
            .font(.system(size: 11))
            .foregroundStyle(PanelStyle.orange)
        } else {
            let row = Self.breakRow(nextBreak: nextBreak, isInviting: false, now: Date())
            statusRow(row.title, row.value)
        }
    }

    /// Matches CreamBlock's inner padding so rows outside it line up with it.
    static let blockInset: CGFloat = 15

    private var divider: some View {
        Rectangle()
            .fill(PanelStyle.line.opacity(0.35))
            .frame(height: 1)
    }

    /// Due: 陪金金 and the three ways to take the break, then pause, all on
    /// the right.
    private var actionRow: some View {
        let isInviting = invitationText != nil
        let isOnBreak = breakEndsAt != nil
        return HStack(spacing: 8) {
            if isInviting || isOnBreak {
                Text(isOnBreak ? "喘口氣中" : "陪金金")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isInviting ? PanelStyle.orange : PanelStyle.muted)
            }
            Spacer(minLength: 0)
            ForEach(Self.visibleControls(controls, isInviting: isInviting, isOnBreak: isOnBreak), id: \.title) { control in
                controlButton(control, emphasized: isInviting || control == .start(breakActivity ?? .rest) && isOnBreak && !breakActivityPaused)
            }
        }
    }

    private func perform(_ control: PopoverControl) {
        switch control {
        case .start(let activity): onStart(activity)
        case .pauseReminders: onPauseReminders()
        case .resumeReminders: onResumeReminders()
        case .stopActivity: onSetBreakActivityPaused(true)
        case .resumeActivity: onSetBreakActivityPaused(false)
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
        case .depleted: FloatingPuppyPlacement.remainder(BreakInvitation.depletedLine)
        }
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 11))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
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
