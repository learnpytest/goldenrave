import Foundation

public struct UsageRecord: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let activeSeconds: TimeInterval
    public let mode: TrackingMode
    public let appName: String?
    public let windowTitle: String?
    public let browserURL: URL?

    public init(
        start: Date,
        end: Date,
        activeSeconds: TimeInterval,
        mode: TrackingMode,
        appName: String? = nil,
        windowTitle: String? = nil,
        browserURL: URL? = nil
    ) {
        self.start = start
        self.end = end
        self.activeSeconds = activeSeconds
        self.mode = mode
        self.appName = appName
        self.windowTitle = windowTitle
        self.browserURL = browserURL
    }
}

public struct BreakEventRecord: Equatable, Sendable {
    public let date: Date
    public let action: BreakAction

    public init(date: Date, action: BreakAction) {
        self.date = date
        self.action = action
    }
}
