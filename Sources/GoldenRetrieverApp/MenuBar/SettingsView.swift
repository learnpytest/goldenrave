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
            minutesRow("工作一次", value: $workMinutes, range: BreakPolicy.workMinutesRange, step: 5)
                .padding(.vertical, Self.rowPadding)
                .padding(.horizontal, PopoverView.blockInset)
            PanelDivider()
            minutesRow("休息一次", value: $restMinutes, range: BreakPolicy.restMinutesRange, step: 1)
                .padding(.vertical, Self.rowPadding)
                .padding(.horizontal, PopoverView.blockInset)
            PanelDivider()
            toggleRow("休息時顯示小金金", options: PetVisibility.allCases.map { ($0.title, $0 == .show) }, selected: showsPet) { showsPet = $0 }
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
            Button("清除本機資料") { showingDeleteConfirmation = true }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(PanelStyle.muted)
                .padding(.vertical, Self.rowPadding)
                .padding(.horizontal, PopoverView.blockInset)
            PanelDivider()
            HStack {
                Text("目前版本 v\(currentVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(PanelStyle.muted)
                Spacer()
                // Notify only: the release page is where the new dmg is downloaded.
                if let update {
                    Button("有新版本 v\(update.version) · 前往更新") { NSWorkspace.shared.open(update.pageURL) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PanelStyle.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
                .padding(.top, Self.rowPadding)
                .padding(.horizontal, PopoverView.blockInset)
        }
        .foregroundStyle(PanelStyle.text)
        // Same edges as the main panel: dividers span the width, text is inset.
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: PopoverLayout.size.width, height: PopoverLayout.settingsHeight, alignment: .top)
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

    /// A two-option pill toggle, the same look for pet visibility and mode.
    private func toggleRow(_ title: String, options: [(String, Bool)], selected: Bool, onSelect: @escaping (Bool) -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer(minLength: 6)
            HStack(spacing: 2) {
                ForEach(options, id: \.0) { option in
                    let isOn = option.1 == selected
                    Button { onSelect(option.1) } label: {
                        Text(option.0)
                            .font(.system(size: 11, weight: isOn ? .heavy : .regular))
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

    private func minutesRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        HStack {
            Text(title).font(.system(size: 12))
            Spacer()
            HStack(spacing: 8) {
                Text("\(value.wrappedValue) 分鐘")
                    .font(.system(size: 13))
                    .monospacedDigit()
                VStack(spacing: 0) {
                    arrow("chevron.up") { value.wrappedValue = min(value.wrappedValue + step, range.upperBound) }
                    arrow("chevron.down") { value.wrappedValue = max(value.wrappedValue - step, range.lowerBound) }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(PanelStyle.line, lineWidth: 1))
        }
    }

    private func arrow(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(PanelStyle.stepperArrow)
                .frame(width: 16, height: 11)
        }
        .buttonStyle(.plain)
    }
}
