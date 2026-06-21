import Foundation
import UserNotifications
import UIKit

@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    private let api = APIClient.shared

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            // Permission denied — not fatal, user can enable later in Settings
        }
    }

    func registerDeviceToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        struct Body: Encodable { let token: String; let platform: String }
        try? await api.requestVoid(
            "/users/me/push-token",
            method: "POST",
            body: Body(token: token, platform: "ios")
        )
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    // Show notifications even when app is in the foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .badge, .sound])
    }

    // Handle notification tap — navigate based on payload
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler handler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let route = userInfo["route"] as? String {
            NotificationCenter.default.post(name: .pushNotificationTapped, object: route)
        }
        handler()
    }
}

extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("PushNotificationTapped")
}
