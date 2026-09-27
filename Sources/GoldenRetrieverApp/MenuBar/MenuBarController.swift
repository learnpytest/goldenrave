import AppKit
import Combine
import GoldenRetrieverCore
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let runtime: AppRuntime
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var runtimeSubscription: AnyCancellable?
    private let player = DogAnimationPlayer()
    private var frameTimer: Timer?
    private var currentAnimation: DogAnimation?
    private var animationStartedAt = Date()
    private var shownFrame: (animation: DogAnimation, index: Int)?
    private var floatingPuppy: FloatingPuppyController?

    init(runtime: AppRuntime) {
        self.runtime = runtime
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.isVisible = true
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        statusItem.button?.imagePosition = .imageLeading
        // Frames are already menu-bar sized; letting AppKit scale them down
        // to fit a fixed-length item is what made the puppy tiny.
        statusItem.button?.imageScaling = .scaleNone
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)

        popover.behavior = .transient
        // The A-version panel is a light cream design; keep the popover chrome light too.
        popover.appearance = NSAppearance(named: .aqua)
        popover.animates = true
        // Built once and kept: the root view observes the runtime, so updates
        // re-render in place. Rebuilding the controller on every change made
        // the open popover flash.
        let hostingController = NSHostingController(rootView: PopoverRootView(runtime: runtime))
        hostingController.sizingOptions = []
        popover.contentViewController = hostingController
        popover.contentSize = PopoverLayout.size

        floatingPuppy = FloatingPuppyController(
            playbackAt: { [runtime] date in runtime.dogPlayback(at: date) },
            lineAt: { [runtime] date in runtime.invitationText(at: date) },
            onClick: { [weak self] in self?.showPopover() }
        )

        runtimeSubscription = runtime.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }

        refresh()

    }

    deinit {
        frameTimer?.invalidate()
        runtimeSubscription?.cancel()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func refresh() {
        let configuration = MenuBarStatusConfiguration(
            snapshot: runtime.snapshot,
            dogState: runtime.dogState
        )
        let button = statusItem.button
        button?.title = configuration.title
        if runtime.invitationStartedAt != nil, runtime.showsPet {
            floatingPuppy?.show()
        } else {
            floatingPuppy?.hide()
        }
        shownFrame = nil
        renderFrame()
        button?.toolTip = configuration.accessibilityLabel
        button?.setAccessibilityLabel(configuration.accessibilityLabel)

    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func renderFrame(now: Date = Date()) {
        // While the puppy is out on the desktop, the menu bar keeps only the timer.
        if floatingPuppy?.isVisible == true {
            if statusItem.button?.image != nil { statusItem.button?.image = nil }
            scheduleNextFrame(in: 0.5)
            return
        }
        let playback = runtime.dogPlayback(at: now)
        let animation = playback.animation
        if animation != currentAnimation {
            currentAnimation = animation
            animationStartedAt = playback.startedAt ?? now
        }
        let frames = player.menuBarFrames(for: animation)
        let elapsed = now.timeIntervalSince(animationStartedAt)
        let frameDuration = player.menuBarFrameDuration(for: animation)
        let index = DogAnimationPlayer.frameIndex(
            elapsed: elapsed,
            frameDuration: frameDuration,
            frameCount: frames.count,
            loops: player.loops(animation)
        )
        scheduleNextFrame(in: DogAnimationPlayer.secondsUntilNextFrame(elapsed: elapsed, frameDuration: frameDuration))
        if let shownFrame, shownFrame.animation == animation, shownFrame.index == index {
            return
        }
        shownFrame = (animation, index)
        statusItem.button?.image = frames.isEmpty ? fallbackImage() : frames[index]
    }

    private func scheduleNextFrame(in seconds: TimeInterval) {
        frameTimer?.invalidate()
        let timer = Timer(timeInterval: max(seconds, 0.01), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.renderFrame()
            }
        }
        timer.tolerance = 0
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    private func fallbackImage() -> NSImage? {
        NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "小金金")
    }
}

@MainActor
private struct PopoverRootView: View {
    @ObservedObject var runtime: AppRuntime

    var body: some View {
        content
            .background(PanelStyle.panel)
    }

    @ViewBuilder
    private var content: some View {
        if runtime.showStatistics, let store = runtime.store {
            StatisticsView(store: store, range: .today)
                .overlay(alignment: .topTrailing) {
                    Button("返回", action: runtime.openSettings)
                        .buttonStyle(.link)
                        .padding()
                }
        } else if runtime.showSettings {
            SettingsView(
                mode: Binding(
                    get: { runtime.trackingMode },
                    set: runtime.setTrackingMode
                ),
                workMinutes: Binding(
                    get: { runtime.workMinutes },
                    set: { runtime.setBreakMinutes(work: $0, rest: runtime.restMinutes) }
                ),
                restMinutes: Binding(
                    get: { runtime.restMinutes },
                    set: { runtime.setBreakMinutes(work: runtime.workMinutes, rest: $0) }
                ),
                isAwaitingPermission: runtime.isAwaitingDetailedPermission,
                onClose: runtime.closeSecondaryView,
                onOpenStatistics: runtime.openStatistics,
                onDeleteData: runtime.deleteAllData
            )
        } else {
            PopoverView(
                snapshot: runtime.snapshot,
                dogState: runtime.dogState,
                nextBreak: runtime.nextBreak,
                breakEndsAt: runtime.breakEndsAt,
                breakActivity: runtime.breakActivity,
                remindersPaused: runtime.remindersPaused,
                invitationText: runtime.invitationText(at: Date()),
                invitationTextAt: runtime.invitationText(at:),
                showsPet: runtime.showsPet,
                onStart: { [runtime] activity in runtime.startBreak(activity) },
                onPauseReminders: runtime.pauseReminders,
                onResumeReminders: runtime.resumeReminders,
                onEndBreak: runtime.endBreak,
                onOpenSettings: runtime.openSettings,
                onSetShowsPet: runtime.setShowsPet
            )
        }
    }
}
