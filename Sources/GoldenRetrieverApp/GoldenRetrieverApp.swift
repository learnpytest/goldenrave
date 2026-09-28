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
    @Published private(set) var showsPet: Bool
    @Published private(set) var availableUpdate: AvailableUpdate?
    let updateChecker = UpdateChecker()
    private var lastUpdateCheck: Date?

    private var dependencies: AppDependencies?
    private let activitySource = SystemActivitySource()
    private var timer: Timer?
    @Published private(set) var breakEndsAt: Date?
    @Published private(set) var breakActivity: BreakActivity?
    @Published private(set) var breakActivityPaused = false
    @Published private(set) var invitationStartedAt: Date?
    @Published private(set) var remindersPaused = false
    /// Set after the puppy gives up inviting a break; cleared when a break starts.
    private var puppyIsDepleted = false
    private var activeSessionStart: Date?
    /// When the last break ended; 連續使用 counts from here.
    private var workCountsFrom: Date?
    private var animationDirector = DogAnimationDirector()
    private let preferences = AppPreferences()
    private var permissionTimer: Timer?

    init() {
        workMinutes = preferences.workMinutes
        restMinutes = preferences.restMinutes
        showsPet = preferences.showsFloatingPuppy
        dependencies = try? AppDependencies.live()
        trackingMode = dependencies?.trackingController.mode ?? .privateMode
        if dependencies?.trackingController.isAwaitingPermission == true {
            waitForDetailedPermission()
        }
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
                self?.checkForUpdates()
            }
        }
        checkForUpdates()
    }

    /// At most once per `UpdateChecker.interval`, unless forced (settings opened).
    func checkForUpdates(force: Bool = false, now: Date = Date()) {
        if !force, let lastUpdateCheck, now.timeIntervalSince(lastUpdateCheck) < UpdateChecker.interval { return }
        lastUpdateCheck = now
        let checker = updateChecker
        Task { [weak self] in
            let update = await checker.check()
            await MainActor.run { self?.availableUpdate = update }
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
            breakActivityPaused = false
            workCountsFrom = now
            animationDirector.breakCompleted(at: now, withBall: Bool.random())
        }
        let sample = activitySource.sample(at: now)
        let previousSnapshot = snapshot
        let engineSnapshot = dependencies.activityEngine.ingest(sample)
        if engineSnapshot.currentSession == 0 {
            workCountsFrom = nil
        }
        snapshot = UsageSnapshot(
            isActive: engineSnapshot.isActive,
            currentSession: WorkSessionClock.session(
                engineSession: engineSnapshot.currentSession,
                isOnBreak: breakEndsAt != nil,
                countsFrom: workCountsFrom,
                now: now
            ),
            todayTotal: engineSnapshot.todayTotal
        )
        if sample.kind == .active {
            if activeSessionStart == nil {
                activeSessionStart = now
            }
            if dependencies.trackingController.mode == .detailed {
                _ = try? dependencies.trackingController.capture()
            }
            // Saved every tick, not only when the user goes idle: quitting or
            // updating the app mid-session used to drop the whole session.
            if let activeSessionStart {
                try? dependencies.store.saveOngoing(session: UsageRecord(
                    start: activeSessionStart,
                    end: now,
                    activeSeconds: max(snapshot.currentSession, now.timeIntervalSince(activeSessionStart)),
                    mode: dependencies.trackingController.mode
                ))
            }
        } else if let activeSessionStart, previousSnapshot.isActive {
            let activeSeconds = max(
                previousSnapshot.currentSession,
                now.timeIntervalSince(activeSessionStart)
            )
            try? dependencies.store.saveOngoing(session: UsageRecord(
                start: activeSessionStart,
                end: now,
                activeSeconds: activeSeconds,
                mode: dependencies.trackingController.mode
            ))
            dependencies.store.finishOngoingSession()
            self.activeSessionStart = nil
        }
        let isOnBreak = breakEndsAt != nil
        if !remindersPaused, sample.kind == .active, !isOnBreak {
            if nextBreak == nil {
                let sessionStart = now.addingTimeInterval(-snapshot.currentSession)
                nextBreak = dependencies.scheduler.nextBreak(after: sessionStart)
            }
        } else if sample.kind == .idle {
            // Stepping away counts as the rest 小金金 was waiting for.
            nextBreak = nil
            puppyIsDepleted = false
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
                // Ignored to the end: 小金金 runs out of battery and the break
                // stays due, rather than quietly being rescheduled.
                puppyIsDepleted = true
                invitationStart = due.addingTimeInterval(-warning)
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
            remindersPaused: remindersPaused,
            isDepleted: puppyIsDepleted
        ))
        self.dependencies = dependencies
    }

    func startBreak(_ activity: BreakActivity = .rest) {
        guard let dependencies else { return }
        let now = Date()
        // During a break another choice only switches the activity; the break
        // keeps its end time.
        if breakEndsAt != nil {
            breakActivity = activity
            breakActivityPaused = false
            animationDirector.breakStarted(at: now, activity: activity)
            return
        }
        puppyIsDepleted = false
        breakEndsAt = now.addingTimeInterval(dependencies.scheduler.policy.restInterval)
        breakActivity = activity
        breakActivityPaused = false
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

    func setShowsPet(_ shows: Bool) {
        showsPet = shows
        preferences.showsFloatingPuppy = shows
    }

    func pauseReminders() {
        remindersPaused = true
        puppyIsDepleted = false
        nextBreak = nil
        tick()
    }

    func resumeReminders() {
        remindersPaused = false
        tick()
    }

    /// ⏹ stops the current activity without ending the break; only the
    /// break's own end time returns to work.
    func setBreakActivityPaused(_ paused: Bool) {
        guard breakEndsAt != nil else { return }
        breakActivityPaused = paused
        animationDirector.breakActivity(paused: paused)
    }

    /// The floating bubble's line: the invitation, or during a break what
    /// 小金金 is doing and how long is left.
    func floatingLine(at date: Date) -> String? {
        if let breakEndsAt {
            let title = breakActivityPaused ? "停下來了" : (breakActivity ?? .rest).ongoingTitle
            return "\(title) · 還剩 \(PopoverView.remainingBreakMinutes(until: breakEndsAt, now: date)) 分鐘"
        }
        return invitationText(at: date)
    }

    func invitationText(at date: Date) -> String? {
        guard let invitationStartedAt else { return nil }
        return puppyIsDepleted ? BreakInvitation.depletedLine : BreakInvitation.line(since: invitationStartedAt, now: date).text
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
        checkForUpdates(force: true)
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
