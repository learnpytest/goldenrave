import Foundation
import GoldenRetrieverCore

public struct AppPreferences {
    private enum Key {
        static let workMinutes = "breakWorkMinutes"
        static let restMinutes = "breakRestMinutes"
        static let trackingMode = "trackingMode"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var workMinutes: Int {
        get { defaults.object(forKey: Key.workMinutes) as? Int ?? 45 }
        nonmutating set { defaults.set(newValue, forKey: Key.workMinutes) }
    }

    public var restMinutes: Int {
        get { defaults.object(forKey: Key.restMinutes) as? Int ?? 10 }
        nonmutating set { defaults.set(newValue, forKey: Key.restMinutes) }
    }

    public var trackingMode: TrackingMode {
        get { defaults.string(forKey: Key.trackingMode).flatMap(TrackingMode.init(rawValue:)) ?? .defaultMode }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.trackingMode) }
    }

    public var breakPolicy: BreakPolicy {
        BreakPolicy(workMinutes: workMinutes, restMinutes: restMinutes)
    }
}
