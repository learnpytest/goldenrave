import Foundation
import GoldenRetrieverCore

public struct AppPreferences {
    private enum Key {
        static let workMinutes = "breakWorkMinutes"
        static let restMinutes = "breakRestMinutes"
        static let trackingMode = "trackingMode"
        static let floatingPuppyX = "floatingPuppyX"
        static let floatingPuppyY = "floatingPuppyY"
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

    /// Where the user last dragged the floating puppy; nil until they do.
    public var floatingPuppyOrigin: CGPoint? {
        get {
            guard let x = defaults.object(forKey: Key.floatingPuppyX) as? Double,
                  let y = defaults.object(forKey: Key.floatingPuppyY) as? Double else { return nil }
            return CGPoint(x: x, y: y)
        }
        nonmutating set {
            defaults.set(newValue.map { Double($0.x) }, forKey: Key.floatingPuppyX)
            defaults.set(newValue.map { Double($0.y) }, forKey: Key.floatingPuppyY)
        }
    }

    public var breakPolicy: BreakPolicy {
        BreakPolicy(workMinutes: workMinutes, restMinutes: restMinutes)
    }
}
