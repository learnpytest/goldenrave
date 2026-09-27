import GoldenRetrieverCore
import SwiftUI

public struct SettingsView: View {
    @Binding private var mode: TrackingMode
    @Binding private var workMinutes: Int
    @Binding private var restMinutes: Int
    @Binding private var showsPet: Bool
    private let isAwaitingPermission: Bool
    private let onClose: () -> Void
    private let onDeleteData: () -> Void
    @State private var showingDeleteConfirmation = false

    public init(
        mode: Binding<TrackingMode>,
        workMinutes: Binding<Int> = .constant(45),
        restMinutes: Binding<Int> = .constant(10),
        showsPet: Binding<Bool> = .constant(true),
        isAwaitingPermission: Bool = false,
        onClose: @escaping () -> Void = {},
        onDeleteData: @escaping () -> Void = {}
    ) {
        self._mode = mode
        self._workMinutes = workMinutes
        self._restMinutes = restMinutes
        self._showsPet = showsPet
        self.isAwaitingPermission = isAwaitingPermission
        self.onClose = onClose
        self.onDeleteData = onDeleteData
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CreamBlock(verticalPadding: 8) {
                VStack(spacing: 6) {
                    minutesRow("工作一次", value: $workMinutes, range: BreakPolicy.workMinutesRange, step: 5)
                    minutesRow("休息一次", value: $restMinutes, range: BreakPolicy.restMinutesRange, step: 1)
                }
            }
            petVisibility
                .padding(.top, 8)
            HStack {
                Text("目前模式").foregroundStyle(PanelStyle.muted)
                Spacer()
                Text(mode == .detailed ? "Detailed" : "Private")
                    .foregroundStyle(Color(hex: 0x2F4F46))
            }
            .font(.system(size: 14))
            .padding(.top, 10)
            modeNote
                .padding(.top, 6)
            Spacer(minLength: 0)
            HStack {
                Button(action: onClose) {
                    Text("返回")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(PanelStyle.chipText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(PanelStyle.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
                Button("清除本機資料") { showingDeleteConfirmation = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(PanelStyle.muted)
            }
        }
        .foregroundStyle(PanelStyle.text)
        .padding(16)
        .frame(width: PopoverLayout.size.width, height: PopoverLayout.size.height, alignment: .top)
        .confirmationDialog(
            "確定清除所有本機使用與休息紀錄？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("清除", role: .destructive, action: onDeleteData)
            Button("取消", role: .cancel) {}
        }
    }

    private var petVisibility: some View {
        HStack {
            Text("休息時顯示小金金")
                .font(.system(size: 12))
            Spacer()
            HStack(spacing: 2) {
                ForEach(PetVisibility.allCases, id: \.self) { option in
                    let isOn = PetVisibility(showsPet: showsPet) == option
                    Button { showsPet = option == .show } label: {
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
    private var modeNote: some View {
        if isAwaitingPermission {
            Text("等待輔助使用權限：到「系統設定 → 隱私權與安全性 → 輔助使用」允許後，會自動切到 Detailed。")
                .font(.system(size: 11))
                .foregroundStyle(PanelStyle.orange)
                .fixedSize(horizontal: false, vertical: true)
        } else if mode == .detailed {
            Button("改回 Private 只記使用時間 →") { mode = .privateMode }
                .buttonStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(PanelStyle.green)
                .underline()
        } else {
            Button("前往 Detailed 詳細設定 →") { mode = .detailed }
                .buttonStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(PanelStyle.green)
                .underline()
        }
    }

    private func minutesRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        HStack {
            Text(title).font(.system(size: 15, weight: .heavy))
            Spacer()
            HStack(spacing: 8) {
                Text("\(value.wrappedValue) 分鐘")
                    .font(.system(size: 15))
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
