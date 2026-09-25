import Foundation
import SwiftData

@Model
final class UsageSessionModel {
    var start: Date
    var end: Date
    var activeSeconds: Double
    var trackingModeRaw: String
    var appName: String?
    var windowTitle: String?
    var browserURLString: String?

    init(record: UsageRecord) {
        self.start = record.start
        self.end = record.end
        self.activeSeconds = record.activeSeconds
        self.trackingModeRaw = record.mode.rawValue
        self.appName = record.appName
        self.windowTitle = record.windowTitle
        self.browserURLString = record.browserURL?.absoluteString
    }

    func record() -> UsageRecord {
        UsageRecord(
            start: start,
            end: end,
            activeSeconds: activeSeconds,
            mode: TrackingMode(rawValue: trackingModeRaw) ?? .privateMode,
            appName: appName,
            windowTitle: windowTitle,
            browserURL: browserURLString.flatMap(URL.init(string:))
        )
    }
}

@Model
final class BreakEventModel {
    var date: Date
    var actionRaw: String

    init(record: BreakEventRecord) {
        self.date = record.date
        self.actionRaw = record.action.rawValue
    }
}
