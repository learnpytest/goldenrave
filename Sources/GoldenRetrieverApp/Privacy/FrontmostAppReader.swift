import AppKit
import ApplicationServices
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
            windowTitle: Self.focusedWindowTitle(of: application),
            browserURL: browserTabReader.readURL()
        )
    }

    /// Reads the focused window's title through the Accessibility API, which
    /// Detailed mode has already been granted.
    private static func focusedWindowTitle(of application: NSRunningApplication) -> String? {
        let app = AXUIElementCreateApplication(application.processIdentifier)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window, CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success,
              let title = title as? String, !title.isEmpty else { return nil }
        return title
    }
}
