import Foundation

public struct BrowserTabReader: Sendable {
    public init() {}

    /// Browser URL access is intentionally optional and never blocks app tracking.
    public func readURL() -> URL? {
        nil
    }
}
