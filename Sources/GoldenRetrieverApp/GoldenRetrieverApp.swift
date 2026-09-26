import AppKit
import Combine
import Foundation
import GoldenRetrieverCore
import SwiftUI

@MainActor
final class AppRuntime: ObservableObject {
    @Published var snapshot = UsageSnapshot(isActive: false, currentSession: 0, todayTotal: 0)
    @Published var dogState: DogState = .idle
    @Published var nextBreak: Date?
    @Published var showStatistics = false
    @Published var showSettings = false
    @Published private(set) var trackingMode: TrackingMode = .privateMode
    @Published private(set) var isAwaitingDetailedPermission = false
    @Published private(set) var workMinutes: Int
    @Published private(set) var restMinutes: Int

    private var dependencies: AppDependencies?
    private let activitySource = SystemActivitySource()
    private var timer: Timer?
    @Published private(set) var breakEndsAt: Date?
    @Published private(set) var breakActivity: BreakActivity?
    @Published private(set) var invitationStartedAt: Date?
    @Published private(set) var remindersPaused = false
    private var activeSessionStart: Date?
    private var animationDirector = DogAnimationDirector()
    private let preferences = AppPreferences()
    private var permissionTimer: Timer?

    init() {
        workMinutes = preferences.workMinutes
        restMinutes = preferences.restMinutes
        dependencies = try? AppDependencies.live()
        trackingMode = dependencies?.trackingController.mode ?? .privateMode
        if dependencies?.trackingController.isAwaitingPermission == true {
            waitForDetailedPermission()
        }
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    deinit {
        timer?.invalidate()
        permissionTimer?.invalidate()
    }

    func tick(now: Date = Date()) {
        guard var dependencies else { return }
        if let breakEndsAt, now >= breakEndsAt {
            self.breakEndsAt = nil
            breakActivity = nil
            animationDirector.breakCompleted(at: now, withBall: Bool.random())
        }
        let sample = activitySource.sample(at: now)
        let previousSnapshot = snapshot
        snapshot = dependencies.activityEngine.ingest(sample)
        if sample.kind == .active {
            if activeSessionStart == nil {
                activeSessionStart = now
            }
            if dependencies.trackingController.mode == .detailed {
                _ = try? dependencies.trackingController.capture()
            }
        } else if let activeSessionStart, previousSnapshot.isActive {
            let activeSeconds = max(
                previousSnapshot.currentSession,
                now.timeIntervalSince(activeSessionStart)
            )
            try? dependencies.store.save(session: UsageRecord(
                start: activeSessionStart,
                end: now,
                activeSeconds: activeSeconds,
                mode: dependencies.trackingController.mode
            ))
            self.activeSessionStart = nil
        }
        let isOnBreak = breakEndsAt != nil
        if !remindersPaused, sample.kind == .active, !isOnBreak {
            if nextBreak == nil {
                let sessionStart = now.addingTimeInterval(-snapshot.currentSession)
                nextBreak = dependencies.scheduler.nextBreak(after: sessionStart)
            }
        } else if sample.kind == .idle {
            nextBreak = nil
        }
        var invitationStart: Date?
        if let due = nextBreak, !remindersPaused, !isOnBreak, sample.kind == .active {
            let warning = dependencies.scheduler.policy.warningWindow
            switch BreakInvitation.phase(due: due, warningWindow: warning, now: now) {
            case .notYet:
                break
            case .inviting(let since):
                invitationStart = since
            case .gaveUp:
                nextBreak = BreakInvitation.nextDue(afterGivingUpAt: now, warningWindow: warning)
            }
        }
        if invitationStartedAt != invitationStart {
            invitationStartedAt = invitationStart
        }
        animationDirector.invitation(startedAt: invitationStart)
        let secondsUntilBreak = nextBreak?.timeIntervalSince(now)
        dogState = DogStateMachine(policy: dependencies.scheduler.policy).state(for: DogStateInput(
            isActive: snapshot.isActive,
            sessionDuration: snapshot.currentSession,
            secondsUntilBreak: secondsUntilBreak,
            isOnBreak: isOnBreak,
            remindersPaused: remindersPaused
        ))
        self.dependencies = dependencies
    }

    func startBreak(_ activity: BreakActivity = .rest) {
        guard let dependencies else { return }
        let now = Date()
        breakEndsAt = now.addingTimeInterval(dependencies.scheduler.policy.restInterval)
        breakActivity = activity
        invitationStartedAt = nil
        animationDirector.invitation(startedAt: nil)
        animationDirector.breakStarted(at: now, activity: activity)
        nextBreak = nil
        dogState = .rest
        try? dependencies.store.save(breakEvent: BreakEventRecord(date: now, action: .started))
    }

    func setBreakMinutes(work: Int, rest: Int) {
        let policy = BreakPolicy(workMinutes: work, restMinutes: rest)
        workMinutes = Int(policy.workInterval / 60)
        restMinutes = Int(policy.restInterval / 60)
        preferences.workMinutes = workMinutes
        preferences.restMinutes = restMinutes
        dependencies?.scheduler = BreakScheduler(policy: policy)
        nextBreak = nil
        tick()
    }

    func pauseReminders() {
        remindersPaused = true
        nextBreak = nil
        tick()
    }

    func resumeReminders() {
        remindersPaused = false
        tick()
    }

    func endBreak() {
        guard let dependencies, breakEndsAt != nil else { return }
        breakEndsAt = nil
        breakActivity = nil
        animationDirector.breakEndedEarly()
        try? dependencies.store.save(breakEvent: BreakEventRecord(date: Date(), action: .completed))
        tick()
    }

    func invitationText(at date: Date) -> String? {
        invitationStartedAt.map { BreakInvitation.line(since: $0, now: date).text }
    }

    func dogPlayback(at date: Date) -> DogAnimationPlayback {
        animationDirector.playback(for: dogState, at: date)
    }

    func openStatistics() {
        showStatistics = true
        showSettings = false
    }

    func openSettings() {
        showSettings = true
        showStatistics = false
    }

    func closeSecondaryView() {
        showStatistics = false
        showSettings = false
    }

    func setTrackingMode(_ requestedMode: TrackingMode) {
        guard let dependencies else { return }
        do {
            if requestedMode == .detailed {
                try dependencies.trackingController.enableDetailedMode()
            } else {
                dependencies.trackingController.disableDetailedMode()
            }
        } catch {
            waitForDetailedPermission()
        }
        syncTrackingMode()
    }

    /// Accessibility is granted in System Settings after our request returns,
    /// so poll briefly instead of making the user pick Detailed again.
    private func waitForDetailedPermission() {
        permissionTimer?.invalidate()
        let deadline = Date().addingTimeInterval(5 * 60)
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self, let controller = self.dependencies?.trackingController else {
                    timer.invalidate()
                    return
                }
                controller.refreshPermission()
                if !controller.isAwaitingPermission || Date() > deadline {
                    timer.invalidate()
                }
                self.syncTrackingMode()
            }
        }
    }

    private func syncTrackingMode() {
        guard let controller = dependencies?.trackingController else { return }
        trackingMode = controller.mode
        isAwaitingDetailedPermission = controller.isAwaitingPermission
        if !controller.isAwaitingPermission {
            preferences.trackingMode = controller.mode
        }
    }

    func deleteAllData() {
        try? dependencies?.store.deleteAll()
    }

    var store: (any LocalStore)? { dependencies?.store }
}

/// An AppKit entry point: with SwiftUI's `App`, the only scene was `Settings`,
/// which macOS opened as a window on every launch and kept re-laying out
/// (~10% CPU sampled 2026-09-26). Settings live in the menu bar popover.
@main
enum GoldenRetrieverMain {
    static func main() {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            app.delegate = AppDelegate.shared
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()

    private var runtime: AppRuntime?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let runtime = AppRuntime()
        self.runtime = runtime
        menuBarController = MenuBarController(runtime: runtime)
    }
}
