# Golden Retriever Menu Bar Companion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu-bar app that automatically tracks computer use, reminds the user to rest, and visualizes the state with one consistent two-month-old Golden Retriever character.

**Architecture:** A Swift Package Manager macOS executable hosts a SwiftUI/AppKit menu-bar shell. Testable core modules produce usage snapshots, break schedules, and dog states; the UI renders those outputs and persists records locally through SwiftData-backed storage. Detailed App/window/browser tracking is opt-in and isolated behind permission-aware protocols.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Package Manager, SwiftData, UserNotifications, Accessibility APIs, macOS 14+.

**Spec:** `docs/superpowers/specs/2026-09-25-golden-retriever-menubar-design.md`

## Global Constraints

- Platform: macOS 14 Sonoma and later.
- Default tracking mode records only active, idle, rest, and duration data.
- Detailed tracking is opt-in and must explain Accessibility permission usage before requesting it.
- All activity data stays local; v1 has no account, cloud API, telemetry, or sync.
- The dog must remain the same two-month-old Golden Retriever across every animation state.
- Do not ship emoji, geometric SVG dogs, generic cartoon dogs, or adult-dog proportions as final animation assets.
- Break reminders are prominent but never lock the keyboard or screen.
- The menu-bar process must not create an unnecessary persistent Dock window.
- The default behavior must avoid saving keystrokes, mouse coordinates, screenshots, or clipboard contents.

## Review Focus

- Idle gaps and sleep/wake transitions must not inflate active usage time; covered by `ActivityEngineTests` and `SessionStoreTests`.
- Switching from Private to Detailed mode must not retroactively invent App/window/browser records; covered by `TrackingModeTests`.
- A break that is delayed, skipped, completed, or crossed over midnight must produce one consistent schedule; covered by `BreakSchedulerTests`.
- The same puppy identity must remain recognizable at menu-bar size and in every state; covered by animation asset checks and the visual acceptance checklist in Task 7.
- Missing Accessibility permission or unsupported browser data must degrade to the highest available privacy-safe level; covered by `PermissionCoordinatorTests` and `DetailedActivityReaderTests`.

---

### Task 1: Create the Swift Package and executable app shell

**Files:**
- Create: `Package.swift`
- Create: `Sources/GoldenRetrieverCore/AppIdentity.swift`
- Create: `Sources/GoldenRetrieverCore/Tracking/TrackingMode.swift`
- Create: `Sources/GoldenRetrieverApp/GoldenRetrieverApp.swift`
- Create: `Sources/GoldenRetrieverApp/Resources/Info.plist`
- Create: `Tests/GoldenRetrieverCoreTests/AppIdentityTests.swift`
- Create: `Scripts/build-app.sh`

**Interfaces:**
- Produces `AppIdentity.bundleIdentifier == "com.rachelchen.GoldenRetriever"`.
- Produces `TrackingMode.privateMode` as the default mode and `TrackingMode.detailed` as the explicit opt-in mode.
- Produces a macOS 14+ executable target named `GoldenRetrieverApp`.
- `Scripts/build-app.sh` accepts an optional configuration argument and creates `dist/GoldenRetriever.app` with `LSUIElement=true`.

- [ ] **Step 1: Write the failing identity test**

```swift
import XCTest
@testable import GoldenRetrieverCore

final class AppIdentityTests: XCTestCase {
    func testBundleIdentifierIsStable() {
        XCTAssertEqual(AppIdentity.bundleIdentifier, "com.rachelchen.GoldenRetriever")
    }
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `swift test --filter AppIdentityTests/testBundleIdentifierIsStable`
Expected: FAIL because `GoldenRetrieverCore` and `AppIdentity` do not exist.

- [ ] **Step 3: Add the package and minimal app shell**

`Package.swift` must declare macOS 14, the `GoldenRetrieverCore` library, the `GoldenRetrieverApp` executable, and test targets. `AppIdentity.swift` must define:

```swift
public enum AppIdentity {
    public static let bundleIdentifier = "com.rachelchen.GoldenRetriever"
}
```

`GoldenRetrieverApp.swift` must compile as a minimal `@main` SwiftUI app with a static `MenuBarExtra` status item and no Dock window. Put `LSUIElement` in the app resource plist so the packaged app behaves as a menu-bar utility. `TrackingMode.swift` must define:

```swift
public enum TrackingMode: String, Codable {
    case privateMode
    case detailed
}
```

- [ ] **Step 4: Run the focused test and build**

Run: `swift test --filter AppIdentityTests/testBundleIdentifierIsStable && swift build`
Expected: PASS and a successful debug build.

- [ ] **Step 5: Add the app packaging script and test it**

The script must run `swift build -c release`, create `dist/GoldenRetriever.app/Contents/{MacOS,Resources}`, copy the executable and `Info.plist`, and print the resulting app path. It must fail if the executable is missing.

Run: `bash Scripts/build-app.sh`
Expected: `dist/GoldenRetriever.app` exists and contains `Contents/MacOS/GoldenRetrieverApp` and `Contents/Info.plist`.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests Scripts
git commit -m "build: scaffold native macOS menu bar app"
```

### Task 2: Implement the testable activity engine

**Files:**
- Create: `Sources/GoldenRetrieverCore/Activity/ActivityModels.swift`
- Create: `Sources/GoldenRetrieverCore/Activity/ActivitySource.swift`
- Create: `Sources/GoldenRetrieverCore/Activity/ActivityEngine.swift`
- Create: `Tests/GoldenRetrieverCoreTests/ActivityEngineTests.swift`
- Modify: `Sources/GoldenRetrieverApp/GoldenRetrieverApp.swift`

**Interfaces:**
- `public enum ActivityKind: Equatable { case active, idle }`
- `public struct ActivitySample: Equatable { public let timestamp: Date; public let kind: ActivityKind }`
- `public struct UsageSnapshot: Equatable { public let isActive: Bool; public let currentSession: TimeInterval; public let todayTotal: TimeInterval }`
- `public protocol ActivitySource { func sample(at date: Date) -> ActivitySample }`
- `public struct ActivityEngine { public init(calendar: Calendar); public mutating func ingest(_ sample: ActivitySample) -> UsageSnapshot }`

- [ ] **Step 1: Write failing tests for active accumulation, idle gaps, and midnight**

Tests must prove that active samples accumulate only while active, an idle sample closes the session without adding idle duration, and an active session crossing midnight contributes only the correct seconds to each day.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `swift test --filter ActivityEngineTests`
Expected: FAIL because the activity models and engine do not exist.

- [ ] **Step 3: Implement immutable samples and a value-type engine**

The engine must use the timestamp on each sample, not wall-clock calls inside the implementation. When an active sample follows an idle sample, start a new session; when an idle sample arrives, close the current session. Expose a `reset()` method for sleep/wake recovery.

- [ ] **Step 4: Add the macOS activity source adapter**

Create `SystemActivitySource` in `Sources/GoldenRetrieverApp/Activity/SystemActivitySource.swift`. It must poll the platform idle-time signal on a timer owned by the app layer and emit `ActivitySample`; keep the core engine independent from AppKit and CoreGraphics.

- [ ] **Step 5: Run all activity tests**

Run: `swift test --filter ActivityEngineTests`
Expected: PASS, including the midnight and idle-gap cases.

- [ ] **Step 6: Commit**

```bash
git add Sources/GoldenRetrieverCore/Activity Sources/GoldenRetrieverApp/Activity Tests/GoldenRetrieverCoreTests/ActivityEngineTests.swift
git commit -m "feat: add testable activity engine"
```

### Task 3: Add the dog state machine and break policy

**Files:**
- Create: `Sources/GoldenRetrieverCore/Dog/DogState.swift`
- Create: `Sources/GoldenRetrieverCore/Dog/DogStateMachine.swift`
- Create: `Sources/GoldenRetrieverCore/Breaks/BreakPolicy.swift`
- Create: `Sources/GoldenRetrieverCore/Breaks/BreakEvent.swift`
- Create: `Tests/GoldenRetrieverCoreTests/DogStateMachineTests.swift`

**Interfaces:**
- `public enum DogState: Equatable { case idle, walk, run, play, jump, rest }`
- `public enum BreakAction: String, Codable { case started, postponed, skipped, completed }`
- `public struct BreakEvent: Equatable { public let date: Date; public let action: BreakAction }`
- `public struct DogStateInput: Equatable { public let isActive: Bool; public let sessionDuration: TimeInterval; public let secondsUntilBreak: TimeInterval?; public let isOnBreak: Bool }`
- `public struct BreakPolicy: Equatable { public let workInterval: TimeInterval; public let restInterval: TimeInterval; public let warningWindow: TimeInterval; public init(workInterval: TimeInterval = 45 * 60, restInterval: TimeInterval = 10 * 60, warningWindow: TimeInterval = 5 * 60) }`
- `public struct DogStateMachine { public init(policy: BreakPolicy); public func state(for input: DogStateInput) -> DogState }`

- [ ] **Step 1: Write failing transition tests**

Pin these transitions: inactive → `idle`; active for less than 5 minutes → `walk`; active from 5 minutes until the warning window → `run`; active after 30 minutes but outside the warning window → `play`; inside the warning window → `jump`; `isOnBreak=true` → `rest`.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `swift test --filter DogStateMachineTests`
Expected: FAIL because the state types and policy do not exist.

- [ ] **Step 3: Implement the pure state machine**

Keep all thresholds in `BreakPolicy` or named constants. The state machine must not read the clock, access the file system, or know about SwiftUI.

- [ ] **Step 4: Run the state-machine tests**

Run: `swift test --filter DogStateMachineTests`
Expected: PASS for every transition and boundary value.

- [ ] **Step 5: Commit**

```bash
git add Sources/GoldenRetrieverCore/Dog Sources/GoldenRetrieverCore/Breaks Tests/GoldenRetrieverCoreTests/DogStateMachineTests.swift
git commit -m "feat: map usage state to puppy behavior"
```

### Task 4: Implement local persistence and statistics

**Files:**
- Create: `Sources/GoldenRetrieverCore/Storage/UsageRecord.swift`
- Create: `Sources/GoldenRetrieverApp/Storage/SwiftDataModels.swift`
- Create: `Sources/GoldenRetrieverApp/Storage/LocalStore.swift`
- Create: `Sources/GoldenRetrieverApp/Storage/CSVExporter.swift`
- Create: `Tests/GoldenRetrieverCoreTests/UsageRecordTests.swift`
- Create: `Tests/GoldenRetrieverAppTests/LocalStoreTests.swift`

**Interfaces:**
- `public struct UsageRecord: Equatable { public let start: Date; public let end: Date; public let activeSeconds: TimeInterval; public let mode: TrackingMode }`
- `protocol LocalStore { func save(session: UsageRecord) throws; func save(breakEvent: BreakEventRecord) throws; func dailyTotal(on date: Date) throws -> TimeInterval; func exportCSV() throws -> Data; func deleteAll() throws }`
- `struct BreakEventRecord: Equatable { let date: Date; let action: BreakAction }`

- [ ] **Step 1: Write failing tests for record aggregation and CSV output**

Use an in-memory SwiftData container. Test that two sessions on one day aggregate correctly, records from another day do not leak into the total, CSV includes stable headers, and `deleteAll()` removes all records.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `swift test --filter LocalStoreTests`
Expected: FAIL because the storage models and store do not exist.

- [ ] **Step 3: Implement SwiftData models backed by a local-only container**

Create models for sessions, break events, and detailed activity segments. Do not configure CloudKit or iCloud. The store must receive its `ModelContainer` through dependency injection so tests can use an in-memory container.

- [ ] **Step 4: Implement aggregation, deletion, and CSV export**

Use calendar-day boundaries from an injected `Calendar`. CSV must include `start`, `end`, `active_seconds`, and `tracking_mode`; detailed columns are present only when detailed records exist.

- [ ] **Step 5: Run storage and core tests**

Run: `swift test --filter LocalStoreTests && swift test --filter UsageRecordTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/GoldenRetrieverCore/Storage Sources/GoldenRetrieverApp/Storage Tests/GoldenRetrieverCoreTests/UsageRecordTests.swift Tests/GoldenRetrieverAppTests/LocalStoreTests.swift
git commit -m "feat: persist local usage and break records"
```

### Task 5: Add privacy modes and permission-aware detailed tracking

**Files:**
- Create: `Sources/GoldenRetrieverApp/Privacy/TrackingModeController.swift`
- Create: `Sources/GoldenRetrieverApp/Privacy/PermissionCoordinator.swift`
- Create: `Sources/GoldenRetrieverApp/Privacy/FrontmostAppReader.swift`
- Create: `Sources/GoldenRetrieverApp/Privacy/BrowserTabReader.swift`
- Create: `Tests/GoldenRetrieverAppTests/TrackingModeTests.swift`
- Create: `Tests/GoldenRetrieverAppTests/PermissionCoordinatorTests.swift`
- Create: `Tests/GoldenRetrieverAppTests/DetailedActivityReaderTests.swift`

**Interfaces:**
- `protocol DetailedActivityReader { func read() -> ActivitySegment? }`
- `struct ActivitySegment: Equatable { let timestamp: Date; let appName: String; let windowTitle: String?; let browserURL: URL? }`
- `protocol PermissionCoordinator { var canReadDetailedActivity: Bool { get }; func requestDetailedActivityPermission() }`
- `final class TrackingModeController { private(set) var mode: TrackingMode; func enableDetailedMode() throws; func disableDetailedMode(); func record(_ segment: ActivitySegment) throws }`

- [ ] **Step 1: Write failing privacy tests**

Test that Private mode never calls `DetailedActivityReader`, enabling Detailed mode without permission returns a typed error and stores no segment, and an unsupported browser result still stores the App/window portion without a URL.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `swift test --filter TrackingModeTests && swift test --filter PermissionCoordinatorTests && swift test --filter DetailedActivityReaderTests`
Expected: FAIL because the privacy interfaces do not exist.

- [ ] **Step 3: Implement mode gating and typed permission errors**

Use `TrackingMode.privateMode` as the initial value. Never switch modes implicitly. Provide an error that contains a user-facing explanation and a recovery action when Accessibility permission is unavailable.

- [ ] **Step 4: Implement AppKit readers behind protocols**

`FrontmostAppReader` reads the active application and optional window title only after permission is available. `BrowserTabReader` supports the first browser adapter selected for v1 and returns `nil` for unsupported or unavailable browser data; it must not block the rest of detailed tracking.

- [ ] **Step 5: Run privacy tests and verify no sensitive payload leaves the process**

Run: `swift test --filter TrackingModeTests && swift test --filter PermissionCoordinatorTests && swift test --filter DetailedActivityReaderTests`
Expected: PASS; tests must use fakes and must not launch a real browser.

- [ ] **Step 6: Commit**

```bash
git add Sources/GoldenRetrieverApp/Privacy Tests/GoldenRetrieverAppTests
git commit -m "feat: gate detailed tracking behind explicit privacy mode"
```

### Task 6: Implement break scheduling and notifications

**Files:**
- Create: `Sources/GoldenRetrieverCore/Breaks/BreakScheduler.swift`
- Create: `Sources/GoldenRetrieverApp/Notifications/NotificationPresenter.swift`
- Create: `Tests/GoldenRetrieverCoreTests/BreakSchedulerTests.swift`

**Interfaces:**
- `public struct BreakScheduler { public init(policy: BreakPolicy, calendar: Calendar); public func nextBreak(after sessionStart: Date) -> Date; public func apply(_ action: BreakAction, at date: Date) -> Date? }`
- `protocol NotificationPresenter { func requestAuthorization() async throws; func presentBreakWarning(secondsRemaining: TimeInterval); func presentBreakDue() }`

- [ ] **Step 1: Write failing schedule tests**

Test the 45-minute default work interval, 5-minute warning window, 10-minute rest interval, postponing by 10 minutes, skipping once, completing a break, and sessions that cross midnight.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `swift test --filter BreakSchedulerTests`
Expected: FAIL because the scheduler does not exist.

- [ ] **Step 3: Implement deterministic scheduling**

Keep scheduling pure and inject dates from the caller. `postponed` returns a new due date; `skipped` records the action and schedules the next work interval; `completed` starts the next work interval after the rest interval.

- [ ] **Step 4: Implement UserNotifications delivery**

Request notification authorization from Settings, not on first launch without explanation. Notification copy must identify the puppy and offer a path back to the app; action handling must route to `BreakScheduler` rather than mutate state inside the notification layer.

- [ ] **Step 5: Run scheduler tests**

Run: `swift test --filter BreakSchedulerTests`
Expected: PASS for all boundary cases.

- [ ] **Step 6: Commit**

```bash
git add Sources/GoldenRetrieverCore/Breaks Sources/GoldenRetrieverApp/Notifications Tests/GoldenRetrieverCoreTests/BreakSchedulerTests.swift
git commit -m "feat: schedule non-blocking rest reminders"
```

### Task 7: Add the canonical puppy animation system and menu-bar UI

**Files:**
- Create: `Sources/GoldenRetrieverApp/Dog/DogAnimationPlayer.swift`
- Create: `Sources/GoldenRetrieverApp/Dog/DogAnimationView.swift`
- Create: `Sources/GoldenRetrieverApp/MenuBar/MenuBarView.swift`
- Create: `Sources/GoldenRetrieverApp/MenuBar/PopoverView.swift`
- Create: `Sources/GoldenRetrieverApp/MenuBar/SettingsView.swift`
- Create: `Resources/Animation/golden-retriever-puppy-reference.png`
- Create: `Resources/Animation/walk/`, `Resources/Animation/run/`, `Resources/Animation/play/`, `Resources/Animation/jump/`, `Resources/Animation/rest/`
- Create: `Tests/GoldenRetrieverAppTests/DogAnimationPlayerTests.swift`

**Interfaces:**
- `struct DogAnimationPlayer { func frames(for state: DogState) -> [Image]; func frameDuration(for state: DogState) -> Duration }`
- `struct DogAnimationView: View { let state: DogState; let player: DogAnimationPlayer }`
- `struct MenuBarView: View { let snapshot: UsageSnapshot; let dogState: DogState }`

- [ ] **Step 1: Add the canonical reference and write asset tests**

Copy the approved two-month-old Golden Retriever reference into `Resources/Animation/golden-retriever-puppy-reference.png`. Add tests that every required state has a non-empty frame list and that the resource bundle contains the canonical reference.

- [ ] **Step 2: Run the asset tests and verify they fail**

Run: `swift test --filter DogAnimationPlayerTests`
Expected: FAIL because the animation player and frame resources do not exist.

- [ ] **Step 3: Produce consistent frame sets from the canonical reference**

Create frame sets for `walk`, `run`, `play`, `jump`, and `rest`. Keep one puppy identity, identical coat colors and facial proportions, with only pose and motion changing. The menu-bar-sized frames must preserve floppy ears, rounded puppy head, short legs, and golden fur. Do not substitute emoji, geometric drawings, or unrelated generated dogs.

- [ ] **Step 4: Implement frame playback**

`DogAnimationPlayer` must select frames by `DogState`, loop them without allocating new image objects on every tick, and expose state-specific timing. The `rest` loop must include visible breathing and blinking rather than a static frame.

- [ ] **Step 5: Build the menu-bar shell and Popover**

Render the dog plus the current continuous-use duration in `MenuBarView`. `PopoverView` must show today total, current session, next break, completed breaks, and actions for start break, postpone 10 minutes, pause reminders, and open statistics. `SettingsView` must expose Private/Detailed mode and explain Accessibility permission before requesting it.

- [ ] **Step 6: Run UI and asset tests**

Run: `swift test --filter DogAnimationPlayerTests && swift build`
Expected: PASS and a successful build with packaged resources.

- [ ] **Step 7: Perform the visual acceptance check**

Open the packaged app and verify at menu-bar size and Popover size:

1. The dog looks like the approved two-month-old Golden Retriever reference.
2. Walking, running, playing, jumping, and resting are visibly different.
3. The rest state shows breathing and the jump state reads as a reminder.
4. No frame looks like an adult dog, generic cartoon, emoji, or geometric stand-in.

- [ ] **Step 8: Commit**

```bash
git add Sources/GoldenRetrieverApp/Dog Sources/GoldenRetrieverApp/MenuBar Resources/Animation Tests/GoldenRetrieverAppTests/DogAnimationPlayerTests.swift
git commit -m "feat: add canonical puppy animation and menu bar UI"
```

### Task 8: Wire the application composition root and statistics flow

**Files:**
- Modify: `Sources/GoldenRetrieverApp/GoldenRetrieverApp.swift`
- Create: `Sources/GoldenRetrieverApp/App/AppDependencies.swift`
- Create: `Sources/GoldenRetrieverApp/Statistics/StatisticsView.swift`
- Create: `Tests/GoldenRetrieverAppTests/AppCompositionTests.swift`

**Interfaces:**
- `struct AppDependencies { var activityEngine: ActivityEngine; let store: LocalStore; let scheduler: BreakScheduler; let trackingController: TrackingModeController; let notificationPresenter: NotificationPresenter }`
- `struct StatisticsView: View { let store: LocalStore; let range: StatisticsRange }`
- `enum StatisticsRange { case today, lastSevenDays, thisMonth }`

- [ ] **Step 1: Write failing composition tests**

Test that the app starts in Private mode, uses one shared store and scheduler, and routes a completed session to both the current snapshot and the daily statistics view.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `swift test --filter AppCompositionTests`
Expected: FAIL because the dependency container and statistics view do not exist.

- [ ] **Step 3: Implement dependency injection**

Create production dependencies in the app entry point and test dependencies with fake activity, storage, permission, and notification implementations. Avoid singletons so core behavior remains deterministic in tests.

- [ ] **Step 4: Implement daily/weekly/monthly statistics**

Use `LocalStore` aggregation only. The view must not read raw App/window/browser data in Private mode and must show a clear empty state when there is no history.

- [ ] **Step 5: Run the complete test suite**

Run: `swift test`
Expected: PASS for all core and app tests.

- [ ] **Step 6: Commit**

```bash
git add Sources/GoldenRetrieverApp/App Sources/GoldenRetrieverApp/Statistics Tests/GoldenRetrieverAppTests/AppCompositionTests.swift Sources/GoldenRetrieverApp/GoldenRetrieverApp.swift
git commit -m "feat: compose usage tracking and statistics flows"
```

### Task 9: Package, document, and verify the first local release

**Files:**
- Modify: `Scripts/build-app.sh`
- Create: `Scripts/run-checks.sh`
- Create: `README.md`
- Create: `docs/privacy.md`
- Create: `docs/animation-acceptance.md`

- [ ] **Step 1: Write the verification script**

`Scripts/run-checks.sh` must run, in order:

```bash
swift test
swift build -c release
bash Scripts/build-app.sh
```

It must stop on the first failure and print the app bundle path on success.

- [ ] **Step 2: Add user-facing documentation**

`README.md` must explain installation from the local app bundle, Private versus Detailed mode, the Accessibility permission, break controls, and how to remove local data. `docs/privacy.md` must enumerate every stored field and explicitly state that keystrokes, mouse coordinates, screenshots, clipboard contents, accounts, and cloud sync are not used. `docs/animation-acceptance.md` must embed the visual acceptance checklist from the spec.

- [ ] **Step 3: Run the release checks**

Run: `bash Scripts/run-checks.sh`
Expected: all tests pass, release build succeeds, and `dist/GoldenRetriever.app` is created.

- [ ] **Step 4: Inspect the packaged app manually**

Launch the local app bundle, verify the menu-bar-only behavior, open the Popover, switch between Private and Detailed settings without granting permission accidentally, trigger a short test break policy, and confirm the puppy animation remains consistent at both sizes.

- [ ] **Step 5: Commit the release scaffolding**

```bash
git add Scripts README.md docs/privacy.md docs/animation-acceptance.md
git commit -m "docs: document local privacy and release verification"
```

## Execution Handoff

Implementation must begin only after this plan is reviewed. The eventual execution should create or select a `codex/` branch before code work, then implement one task at a time with the task's tests and commit. The GitHub repository under `rachelchen05` should be created only after the local app and verification checks are complete and the user explicitly asks to publish it.
