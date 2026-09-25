import ApplicationServices

public protocol PermissionCoordinator {
    var canReadDetailedActivity: Bool { get }
    func requestDetailedActivityPermission()
}

public struct SystemPermissionCoordinator: PermissionCoordinator {
    public init() {}

    public var canReadDetailedActivity: Bool {
        AXIsProcessTrusted()
    }

    public func requestDetailedActivityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
