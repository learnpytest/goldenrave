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

    private var dependencies: AppDependencies?
    private let activitySource = SystemActivitySource()
    private var timer: Timer?
    private var breakEndsAt: Date?
    private var remindersPaused = false
    private var activeSessionStart: Date?

    init() {
        dependencies = try? AppDependencies.live()
        trackingMode = dependencies?.trackingController.mode ?? .privateMode
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func tick(now: Date = Date()) {
        guard var dependencies else { return }
        if let breakEndsAt, now >= breakEndsAt {
            self.breakEndsAt = nil
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
        let secondsUntilBreak = nextBreak?.timeIntervalSince(now)
        dogState = DogStateMachine(policy: dependencies.scheduler.policy).state(for: DogStateInput(
            isActive: snapshot.isActive,
            sessionDuration: snapshot.currentSession,
            secondsUntilBreak: secondsUntilBreak,
            isOnBreak: isOnBreak
        ))
        self.dependencies = dependencies
    }

    func startBreak() {
        guard let dependencies else { return }
        let now = Date()
        breakEndsAt = now.addingTimeInterval(dependencies.scheduler.policy.restInterval)
        nextBreak = nil
        dogState = .rest
        try? dependencies.store.save(breakEvent: BreakEventRecord(date: now, action: .started))
    }

    func postpone() {
        guard let dependencies, let due = nextBreak else { return }
        nextBreak = dependencies.scheduler.apply(.postponed, at: due)
        try? dependencies.store.save(breakEvent: BreakEventRecord(date: Date(), action: .postponed))
    }

    func pauseReminders() {
        remindersPaused = true
        nextBreak = nil
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
            trackingMode = dependencies.trackingController.mode
        } catch {
            trackingMode = dependencies.trackingController.mode
        }
    }

    func deleteAllData() {
        try? dependencies?.store.deleteAll()
    }

    var store: (any LocalStore)? { dependencies?.store }
}

@main
@MainActor
struct GoldenRetrieverApp: App {
    private let menuBarController: MenuBarController

    init() {
        menuBarController = MenuBarController(runtime: AppRuntime())
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
