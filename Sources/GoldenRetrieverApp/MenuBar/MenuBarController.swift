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

    init(runtime: AppRuntime) {
        self.runtime = runtime
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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
    }

    deinit {
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
        button?.image = statusImage(for: runtime.dogState)
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
                onStartBreak: runtime.startBreak,
                onPostpone: runtime.postpone,
                onPauseReminders: runtime.pauseReminders,
                onOpenStatistics: runtime.openStatistics,
                onOpenSettings: runtime.openSettings
            )
        }
    }

    private func statusImage(for state: DogState) -> NSImage? {
        guard let url = DogAnimationPlayer.resourceURL(for: state),
              let image = NSImage(contentsOf: url) else {
            return fallbackImage()
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }

    private func fallbackImage() -> NSImage? {
        NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "小黃金")
    }
}
