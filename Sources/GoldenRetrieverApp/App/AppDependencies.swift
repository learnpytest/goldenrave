import GoldenRetrieverCore

public struct AppDependencies {
    public var activityEngine: ActivityEngine
    public let store: any LocalStore
    public let scheduler: BreakScheduler
    public let trackingController: TrackingModeController
    public let notificationPresenter: any NotificationPresenter

    public init(
        activityEngine: ActivityEngine,
        store: any LocalStore,
        scheduler: BreakScheduler,
        trackingController: TrackingModeController,
        notificationPresenter: any NotificationPresenter
    ) {
        self.activityEngine = activityEngine
        self.store = store
        self.scheduler = scheduler
        self.trackingController = trackingController
        self.notificationPresenter = notificationPresenter
    }

    public static func live() throws -> AppDependencies {
        let store = try SwiftDataLocalStore.makeDefault()
        let permission = SystemPermissionCoordinator()
        let reader = FrontmostAppReader(permission: permission)
        let trackingController = TrackingModeController(
            reader: reader,
            permission: permission,
            store: store
        )
        return AppDependencies(
            activityEngine: ActivityEngine(),
            store: store,
            scheduler: BreakScheduler(),
            trackingController: trackingController,
            notificationPresenter: UserNotificationPresenter()
        )
    }
}
