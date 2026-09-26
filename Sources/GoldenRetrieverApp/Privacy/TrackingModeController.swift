import Foundation
import GoldenRetrieverCore

public struct ActivitySegment: Equatable, Sendable {
    public let timestamp: Date
    public let appName: String
    public let windowTitle: String?
    public let browserURL: URL?

    public init(timestamp: Date, appName: String, windowTitle: String?, browserURL: URL?) {
        self.timestamp = timestamp
        self.appName = appName
        self.windowTitle = windowTitle
        self.browserURL = browserURL
    }
}

public protocol DetailedActivityReader {
    func read() -> ActivitySegment?
}

public protocol DetailedActivityStore {
    func save(segment: ActivitySegment) throws
}

public struct DetailedActivityPermissionError: Error, Equatable, LocalizedError, Sendable {
    public let explanation: String
    public let recoveryAction: String

    public init(
        explanation: String = "Detailed mode needs Accessibility permission to read the frontmost app.",
        recoveryAction: String = "Open System Settings > Privacy & Security > Accessibility, allow Golden Retriever, then try again."
    ) {
        self.explanation = explanation
        self.recoveryAction = recoveryAction
    }

    public var errorDescription: String? {
        "\(explanation) \(recoveryAction)"
    }
}

public final class TrackingModeController {
    public private(set) var mode: TrackingMode
    /// Set after Detailed was requested without Accessibility permission, so
    /// granting it later in System Settings switches the mode without another click.
    public private(set) var isAwaitingPermission = false

    private let reader: DetailedActivityReader
    private let permission: any PermissionCoordinator
    private let store: DetailedActivityStore

    public init(
        reader: DetailedActivityReader,
        permission: any PermissionCoordinator,
        store: DetailedActivityStore,
        mode: TrackingMode = .privateMode
    ) {
        self.reader = reader
        self.permission = permission
        self.store = store
        if mode == .detailed, !permission.canReadDetailedActivity {
            self.mode = .privateMode
            self.isAwaitingPermission = true
        } else {
            self.mode = mode
        }
    }

    public func enableDetailedMode() throws {
        guard permission.canReadDetailedActivity else {
            permission.requestDetailedActivityPermission()
            guard permission.canReadDetailedActivity else {
                isAwaitingPermission = true
                throw DetailedActivityPermissionError()
            }
            return try enableDetailedMode()
        }
        isAwaitingPermission = false
        mode = .detailed
    }

    public func disableDetailedMode() {
        isAwaitingPermission = false
        mode = .privateMode
    }

    /// Returns true when a pending Detailed request just became active.
    @discardableResult
    public func refreshPermission() -> Bool {
        guard isAwaitingPermission, permission.canReadDetailedActivity else { return false }
        isAwaitingPermission = false
        mode = .detailed
        return true
    }

    @discardableResult
    public func capture() throws -> ActivitySegment? {
        guard mode == .detailed else { return nil }
        guard permission.canReadDetailedActivity else {
            throw DetailedActivityPermissionError()
        }
        guard let segment = reader.read() else { return nil }
        try record(segment)
        return segment
    }

    public func record(_ segment: ActivitySegment) throws {
        guard mode == .detailed else { return }
        try store.save(segment: segment)
    }
}
