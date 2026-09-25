import GoldenRetrieverCore
import SwiftUI

public struct SettingsView: View {
    @Binding private var mode: TrackingMode
    private let onClose: () -> Void

    public init(mode: Binding<TrackingMode>, onClose: @escaping () -> Void = {}) {
        self._mode = mode
        self.onClose = onClose
    }

    public var body: some View {
        Form {
            Picker("紀錄模式", selection: $mode) {
                Text("Private：只記使用時間").tag(TrackingMode.privateMode)
                Text("Detailed：記錄 app／視窗").tag(TrackingMode.detailed)
            }
            .pickerStyle(.radioGroup)
            if mode == .detailed {
                Text("Detailed 模式需要你在系統設定中明確允許 Accessibility；未允許前不會讀取 app 或視窗資料。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("返回", action: onClose)
        }
        .padding()
        .frame(width: 360)
    }
}
