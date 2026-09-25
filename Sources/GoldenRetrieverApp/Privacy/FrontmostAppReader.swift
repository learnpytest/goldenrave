import AppKit
import Foundation

public struct FrontmostAppReader: DetailedActivityReader {
    private let permission: any PermissionCoordinator
    private let browserTabReader: BrowserTabReader

    public init(
        permission: any PermissionCoordinator,
        browserTabReader: BrowserTabReader = BrowserTabReader()
    ) {
        self.permission = permission
        self.browserTabReader = browserTabReader
    }

    public func read() -> ActivitySegment? {
        guard permission.canReadDetailedActivity,
              let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        let name = application.localizedName ?? application.bundleIdentifier ?? "Unknown app"
        return ActivitySegment(
            timestamp: Date(),
            appName: name,
            windowTitle: nil,
            browserURL: browserTabReader.readURL()
        )
    }
}
