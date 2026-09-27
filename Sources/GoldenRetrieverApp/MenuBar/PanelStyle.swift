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
    static let stepperArrow = Color(hex: 0xC7832D)
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
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(PanelStyle.cream, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
