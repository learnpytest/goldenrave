import AppKit
import GoldenRetrieverCore
import SwiftUI

enum FloatingPuppyPlacement {
    static let margin: CGFloat = 24
    static let dragThreshold: CGFloat = 4

    /// A remembered spot is reused while it still touches a connected screen,
    /// nudged inward so the whole puppy and bubble stay visible.
    static func origin(saved: CGPoint?, size: CGSize, screens: [CGRect]) -> CGPoint {
        if let saved, let screen = screens.first(where: { $0.intersects(CGRect(origin: saved, size: size)) }) {
            return CGPoint(
                x: min(max(saved.x, screen.minX), screen.maxX - size.width),
                y: min(max(saved.y, screen.minY), screen.maxY - size.height)
            )
        }
        guard let screen = screens.first else { return .zero }
        return CGPoint(x: screen.maxX - size.width - margin, y: screen.minY + margin)
    }

    /// The bubble shows only the first half of a line; the popover has it all.
    static func teaser(_ line: String) -> String {
        guard let comma = line.firstIndex(of: "，") else { return line }
        return String(line[..<comma]) + "…"
    }

    /// The popover picks up where the bubble left off.
    static func remainder(_ line: String) -> String {
        guard let comma = line.firstIndex(of: "，") else { return line }
        return "…" + String(line[line.index(after: comma)...])
    }

    static func isDrag(from start: CGPoint, to end: CGPoint) -> Bool {
        hypot(end.x - start.x, end.y - start.y) >= dragThreshold
    }
}

/// Shows the puppy on the desktop while a break invitation is running.
@MainActor
final class FloatingPuppyController {
    static let size = CGSize(width: 180, height: 170)

    private let panel: NSPanel
    private let preferences: AppPreferences
    private let makeContent: () -> NSView
    private let container: DragOrClickView

    init(
        playbackAt: @escaping (Date) -> DogAnimationPlayback,
        lineAt: @escaping (Date) -> String?,
        preferences: AppPreferences = AppPreferences(),
        onClick: @escaping () -> Void
    ) {
        self.preferences = preferences
        panel = FloatingPuppyPanel(
            contentRect: CGRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let hover = HoverState()
        makeContent = {
            let hosting = NSHostingView(rootView: FloatingPuppyView(playbackAt: playbackAt, lineAt: lineAt, hover: hover))
            hosting.frame = CGRect(origin: .zero, size: Self.size)
            return hosting
        }
        let container = DragOrClickView(frame: CGRect(origin: .zero, size: Self.size))
        self.container = container
        container.onClick = onClick
        container.onHover = { hover.isHovering = $0 }
        container.onDragEnded = { [weak self] origin in
            self?.preferences.floatingPuppyOrigin = origin
        }
        panel.contentView = container
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        guard !panel.isVisible else { return }
        let origin = FloatingPuppyPlacement.origin(
            saved: preferences.floatingPuppyOrigin,
            size: Self.size,
            screens: NSScreen.screens.map(\.visibleFrame)
        )
        panel.setFrameOrigin(origin)
        // Built on show and torn down on hide: a hidden panel's TimelineViews
        // kept redrawing, 0.7% → 4.2% CPU while idle (measured 2026-09-27).
        container.addSubview(makeContent())
        panel.orderFrontRegardless()
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        container.subviews.forEach { $0.removeFromSuperview() }
        container.onHover?(false)
    }
}

/// Never takes key focus, so typing keeps going to the app the user is in.
private final class FloatingPuppyPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class HoverState: ObservableObject {
    @Published var isHovering = false
}

private final class DragOrClickView: NSView {
    var onClick: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    var onDragEnded: ((CGPoint) -> Void)?
    private var mouseDownAt: CGPoint?
    private var windowOriginAtMouseDown: CGPoint = .zero
    private var isDragging = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }

    override func mouseDown(with event: NSEvent) {
        mouseDownAt = NSEvent.mouseLocation
        windowOriginAtMouseDown = window?.frame.origin ?? .zero
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownAt else { return }
        let now = NSEvent.mouseLocation
        if !isDragging, FloatingPuppyPlacement.isDrag(from: start, to: now) {
            isDragging = true
        }
        guard isDragging else { return }
        window?.setFrameOrigin(CGPoint(
            x: windowOriginAtMouseDown.x + now.x - start.x,
            y: windowOriginAtMouseDown.y + now.y - start.y
        ))
    }

    override func mouseUp(with event: NSEvent) {
        defer { mouseDownAt = nil }
        if isDragging {
            if let origin = window?.frame.origin { onDragEnded?(origin) }
        } else {
            onClick?()
        }
        isDragging = false
    }
}

private struct FloatingPuppyView: View {
    let playbackAt: (Date) -> DogAnimationPlayback
    let lineAt: (Date) -> String?
    @ObservedObject var hover: HoverState
    private static let dogSide: CGFloat = 120

    var body: some View {
        VStack(spacing: 2) {
            DogAnimationView(playbackAt: playbackAt)
                .frame(width: DogAnimationPlayer.popoverSide, height: DogAnimationPlayer.popoverSide)
                .scaleEffect(Self.dogSide / DogAnimationPlayer.popoverSide)
                .frame(width: Self.dogSide, height: Self.dogSide)
            // Same line as under 小金金陪伴中 in the popover; it only appears on hover.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(FloatingPuppyPlacement.teaser(lineAt(context.date) ?? BreakInvitation.lines[0].text))
            }
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(Color(nsColor: .labelColor))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                )
                .opacity(hover.isHovering ? 1 : 0)
                .animation(.easeOut(duration: 0.15), value: hover.isHovering)
        }
        .padding(.bottom, 6)
        .frame(width: FloatingPuppyController.size.width, height: FloatingPuppyController.size.height, alignment: .bottom)
    }
}
