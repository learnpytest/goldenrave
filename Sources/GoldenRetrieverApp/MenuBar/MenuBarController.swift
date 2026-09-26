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

    init(runtime: AppRuntime) {
        self.runtime = runtime
        statusItem = NSStatusBar.system.statusItem(
            withLength: CGFloat(MenuBarStatusConfiguration.minimumLength)
        )
        super.init()

        statusItem.isVisible = true
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)

        popover.behavior = .transient
        popover.animates = true

        runtimeSubscription = runtime.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }

        refresh()

        frameTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.renderFrame()
            }
        }
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
        renderFrame()
        button?.toolTip = configuration.accessibilityLabel
        button?.setAccessibilityLabel(configuration.accessibilityLabel)

        if popover.isShown {
            installPopoverContent()
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        installPopoverContent()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func installPopoverContent() {
        let hostingController = NSHostingController(rootView: popoverRootView())
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        popover.contentViewController = hostingController
    }

    @ViewBuilder
    private func popoverRootView() -> some View {
        if runtime.showStatistics, let store = runtime.store {
            StatisticsView(store: store, range: .today)
                .overlay(alignment: .topTrailing) {
                    Button("返回", action: runtime.closeSecondaryView)
                        .buttonStyle(.link)
                        .padding()
                }
        } else if runtime.showSettings {
            SettingsView(
                mode: Binding(
                    get: { self.runtime.trackingMode },
                    set: self.runtime.setTrackingMode
                ),
                onClose: runtime.closeSecondaryView,
                onDeleteData: runtime.deleteAllData
            )
        } else {
            PopoverView(
                snapshot: runtime.snapshot,
                dogState: runtime.dogState,
                nextBreak: runtime.nextBreak,
                breakEndsAt: runtime.breakEndsAt,
                remindersPaused: runtime.remindersPaused,
                playbackAt: runtime.dogPlayback(at:),
                onStartBreak: runtime.startBreak,
                onPostpone: runtime.postpone,
                onPauseReminders: runtime.pauseReminders,
                onResumeReminders: runtime.resumeReminders,
                onEndBreak: runtime.endBreak,
                onOpenStatistics: runtime.openStatistics,
                onOpenSettings: runtime.openSettings
            )
        }
    }

    private func renderFrame(now: Date = Date()) {
        let playback = runtime.dogPlayback(at: now)
        let animation = playback.animation
        if animation != currentAnimation {
            currentAnimation = animation
            animationStartedAt = playback.startedAt ?? now
        }
        let frames = player.menuBarFrames(for: animation)
        let index = DogAnimationPlayer.frameIndex(
            elapsed: now.timeIntervalSince(animationStartedAt),
            frameDuration: player.frameDuration(for: animation),
            frameCount: frames.count,
            loops: player.loops(animation)
        )
        if let shownFrame, shownFrame.animation == animation, shownFrame.index == index {
            return
        }
        shownFrame = (animation, index)
        statusItem.button?.image = frames.isEmpty ? fallbackImage() : frames[index]
    }

    private func fallbackImage() -> NSImage? {
        NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "小黃金")
    }
}
