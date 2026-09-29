import AppKit
import GoldenRetrieverCore
import SwiftUI

public struct SettingsView: View {
    @Binding private var mode: TrackingMode
    @Binding private var workMinutes: Int
    @Binding private var restMinutes: Int
    @Binding private var showsPet: Bool
    private let isAwaitingPermission: Bool
    private let currentVersion: String
    private let update: AvailableUpdate?
    private let onClose: () -> Void
    private let onDeleteData: () -> Void
    @State private var showingDeleteConfirmation = false

    public init(
        mode: Binding<TrackingMode>,
        workMinutes: Binding<Int> = .constant(45),
        restMinutes: Binding<Int> = .constant(10),
        showsPet: Binding<Bool> = .constant(true),
        isAwaitingPermission: Bool = false,
        currentVersion: String = "",
        update: AvailableUpdate? = nil,
        onClose: @escaping () -> Void = {},
        onDeleteData: @escaping () -> Void = {}
    ) {
        self._mode = mode
        self._workMinutes = workMinutes
        self._restMinutes = restMinutes
        self._showsPet = showsPet
        self.isAwaitingPermission = isAwaitingPermission
        self.currentVersion = currentVersion
        self.update = update
        self.onClose = onClose
        self.onDeleteData = onDeleteData
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackButton(action: onClose)
                .frame(minHeight: 18)
                .padding(.horizontal, PopoverView.blockInset)
                .padding(.bottom, 8)
            PanelDivider()
            minutesRow("工作一次", value: $workMinutes, range: BreakPolicy.workMinutesRange)
                .padding(.vertical, Self.rowPadding)
                .padding(.horizontal, PopoverView.blockInset)
            PanelDivider()
            minutesRow("休息一次", value: $restMinutes, range: BreakPolicy.restMinutesRange)
                .padding(.vertical, Self.rowPadding)
                .padding(.horizontal, PopoverView.blockInset)
            PanelDivider()
            toggleRow("休息顯示小金金", options: PetVisibility.allCases.map { ($0.title, $0 == .show) }, selected: showsPet) { showsPet = $0 }
                .padding(.vertical, Self.rowPadding)
                .padding(.horizontal, PopoverView.blockInset)
            PanelDivider()
            toggleRow("記錄模式", options: [("Private", false), ("Detailed", true)], selected: mode == .detailed) { detailed in
                mode = detailed ? .detailed : .privateMode
            }
                .padding(.vertical, Self.rowPadding)
                .padding(.horizontal, PopoverView.blockInset)
            if isAwaitingPermission {
                Text("等待輔助使用權限：到「系統設定 → 隱私權與安全性 → 輔助使用」允許後，會自動切到 Detailed。")
                    .font(.system(size: 10))
                    .foregroundStyle(PanelStyle.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)
                    .padding(.horizontal, PopoverView.blockInset)
            }
            PanelDivider()
            Button { showingDeleteConfirmation = true } label: { label("清除本機資料") }
                .buttonStyle(.plain)
                .padding(.vertical, Self.rowPadding)
                .padding(.horizontal, PopoverView.blockInset)
            PanelDivider()
            // A menu-bar-only app has no Dock icon or menu to quit from.
            Button { NSApp.terminate(nil) } label: { label("結束小金金") }
                .buttonStyle(.plain)
                .padding(.vertical, Self.rowPadding)
                .padding(.horizontal, PopoverView.blockInset)
            PanelDivider()
            HStack {
                label("目前版本 v\(currentVersion)")
                Spacer()
                // Notify only: the release page is where the new dmg is downloaded.
                if let update {
                    Button("前往更新 \(update.version) 版") { NSWorkspace.shared.open(update.pageURL) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PanelStyle.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
                .padding(.top, Self.rowPadding)
                .padding(.horizontal, PopoverView.blockInset)
            // A running app cannot be replaced, so the drag-in fails unless
            // 小金金 is quit first.
            if update != nil {
                Text(Self.updateSteps)
                    .font(.system(size: 10))
                    .foregroundStyle(PanelStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .padding(.horizontal, PopoverView.blockInset)
            }
        }
        .foregroundStyle(PanelStyle.text)
        // Same edges as the main panel: dividers span the width, text is inset.
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: PopoverLayout.size.width, height: PopoverLayout.settingsHeight(showsUpdateHint: update != nil), alignment: .top)
        .confirmationDialog(
            "確定清除所有本機使用與休息紀錄？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("清除", role: .destructive, action: onDeleteData)
            Button("取消", role: .cancel) {}
        }
    }

    private static let rowPadding: CGFloat = 7
    static let updateSteps = "更新前先「結束小金金」，再拖進應用程式取代"

    /// A two-option pill toggle, the same look for pet visibility and mode.
    private func toggleRow(_ title: String, options: [(String, Bool)], selected: Bool, onSelect: @escaping (Bool) -> Void) -> some View {
        HStack {
            label(title)
                .lineLimit(1)
            Spacer(minLength: 6)
            HStack(spacing: 2) {
                ForEach(options, id: \.0) { option in
                    let isOn = option.1 == selected
                    Button { onSelect(option.1) } label: {
                        Text(option.0)
                            .font(.system(size: 12, weight: isOn ? .heavy : .regular))
                            .foregroundStyle(isOn ? Color.white : PanelStyle.chipText)
                            .fixedSize()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(isOn ? PanelStyle.orange : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(PanelStyle.chip, in: Capsule())
        }
    }

    /// Every left-hand label matches 總共 on the statistics page.
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(PanelStyle.text)
    }

    /// The box holds only the number: type it, or step it a minute at a time
    /// with its arrows or ↑ / ↓. 分鐘 sits outside. Anything outside the range
    /// snaps to its nearest end.
    private func minutesRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        let clamped = Binding<Int>(
            get: { value.wrappedValue },
            set: { value.wrappedValue = min(max($0, range.lowerBound), range.upperBound) }
        )
        return HStack {
            label(title)
            Spacer()
            // Same capsule, colour and type size as the Show / Hide chips.
            HStack(spacing: 2) {
                TextField("", value: clamped, format: .number)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(PanelStyle.text)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .frame(width: 24)
                    .onKeyPress(.upArrow) {
                        clamped.wrappedValue += 1
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        clamped.wrappedValue -= 1
                        return .handled
                    }
                VStack(spacing: 0) {
                    arrow("chevron.up") { clamped.wrappedValue += 1 }
                    arrow("chevron.down") { clamped.wrappedValue -= 1 }
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 4)
            .padding(.vertical, 2)
            .background(PanelStyle.chip, in: Capsule())
            label("分鐘")
        }
    }

    private func arrow(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(PanelStyle.chipText)
                .frame(width: 14, height: 9)
        }
        .buttonStyle(.plain)
    }
}
