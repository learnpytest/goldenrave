import GoldenRetrieverCore
import SwiftUI

public struct SettingsView: View {
    @Binding private var mode: TrackingMode
    @Binding private var workMinutes: Int
    @Binding private var restMinutes: Int
    private let isAwaitingPermission: Bool
    private let onClose: () -> Void
    private let onDeleteData: () -> Void
    @State private var showingDeleteConfirmation = false

    public init(
        mode: Binding<TrackingMode>,
        workMinutes: Binding<Int> = .constant(45),
        restMinutes: Binding<Int> = .constant(10),
        isAwaitingPermission: Bool = false,
        onClose: @escaping () -> Void = {},
        onDeleteData: @escaping () -> Void = {}
    ) {
        self._mode = mode
        self._workMinutes = workMinutes
        self._restMinutes = restMinutes
        self.isAwaitingPermission = isAwaitingPermission
        self.onClose = onClose
        self.onDeleteData = onDeleteData
    }

    public var body: some View {
        Form {
            Section("休息時間") {
                Stepper(value: $workMinutes, in: BreakPolicy.workMinutesRange, step: 5) {
                    Text("每工作 \(workMinutes) 分鐘休息一次")
                }
                Stepper(value: $restMinutes, in: BreakPolicy.restMinutesRange) {
                    Text("每次休息 \(restMinutes) 分鐘")
                }
            }
            Picker("紀錄模式", selection: $mode) {
                Text("Private：只記使用時間").tag(TrackingMode.privateMode)
                Text("Detailed：記錄 app／視窗").tag(TrackingMode.detailed)
            }
            .pickerStyle(.radioGroup)
            if isAwaitingPermission {
                Text("等待輔助使用權限：在「系統設定 → 隱私權與安全性 → 輔助使用」允許 Golden Retriever 後，會自動切到 Detailed。若清單裡已經打開卻沒有切換，請先把 Golden Retriever 移除（−），再重新加入。")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if mode == .detailed {
                Text("Detailed 模式已使用輔助使用權限讀取前景 app 與視窗名稱。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("清除本機資料", role: .destructive) {
                showingDeleteConfirmation = true
            }
            Button("返回", action: onClose)
        }
        .padding()
        .frame(width: 360)
        .confirmationDialog(
            "確定清除所有本機使用與休息紀錄？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("清除", role: .destructive, action: onDeleteData)
            Button("取消", role: .cancel) {}
        }
    }
}
