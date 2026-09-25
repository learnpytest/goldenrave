import Foundation
import UserNotifications

public protocol NotificationPresenter {
    func requestAuthorization() async throws
    func presentBreakWarning(secondsRemaining: TimeInterval)
    func presentBreakDue()
}

public final class UserNotificationPresenter: NotificationPresenter {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestAuthorization() async throws {
        _ = try await center.requestAuthorization(options: [.alert, .sound])
    }

    public func presentBreakWarning(secondsRemaining: TimeInterval) {
        let minutes = max(1, Int(ceil(secondsRemaining / 60)))
        present(
            title: "小黃金提醒你",
            body: "再工作約 \(minutes) 分鐘，就陪我休息一下吧。"
        )
    }

    public func presentBreakDue() {
        present(
            title: "小黃金要休息囉",
            body: "起來走走、喝口水，再回來陪我玩。"
        )
    }

    private func present(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "golden-retriever-break-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
