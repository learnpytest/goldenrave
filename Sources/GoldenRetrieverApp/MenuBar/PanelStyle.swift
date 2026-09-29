import SwiftUI

/// Colours from Codex's 休息時間面板 A 版 design (2026-09-27).
enum PanelStyle {
    static let panel = Color(hex: 0xFFFDF6)
    static let cream = Color(hex: 0xFFF5DF)
    static let chip = Color(hex: 0xF6E4C9)
    static let line = Color(hex: 0xE8B86A)
    static let text = Color(hex: 0x5B422C)
    static let muted = Color(hex: 0x92704A)
    static let chipText = Color(hex: 0x9A6B3D)
    static let green = Color(hex: 0x388A72)
    static let orange = Color(hex: 0xE98763)
    static let red = Color(hex: 0xE86F63)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// A cream rounded block, the design's grouping container.
struct CreamBlock<Content: View>: View {
    var radius: CGFloat = 15
    var verticalPadding: CGFloat = 13
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 15)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity)
            .background(PanelStyle.cream, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// ‹ 返回 at the top-left of every secondary page, so they all go back the same way.
struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .bold))
                Text("返回")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(PanelStyle.chipText)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The thin rule between rows, shared by the main panel and settings.
struct PanelDivider: View {
    var body: some View {
        Rectangle()
            .fill(PanelStyle.line.opacity(0.35))
            .frame(height: 1)
    }
}
