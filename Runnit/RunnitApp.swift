import SwiftUI

@main
struct RunnitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = AuthService.shared
    @StateObject private var push = PushNotificationService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .onOpenURL { url in
                    DeepLinkHandler.handle(url)
                }
                .task {
                    if auth.isLoggedIn {
                        await push.requestPermission()
                    }
                }
                .onChange(of: auth.isLoggedIn) { _, loggedIn in
                    if loggedIn {
                        Task { await push.requestPermission() }
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    // Refresh Strava status when user returns from Safari after OAuth
                    if phase == .active && auth.isLoggedIn {
                        Task { try? await StravaService.shared.fetchStatus() }
                    }
                }
        }
    }
}

// MARK: - AppDelegate bridge for APNs device token

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await PushNotificationService.shared.registerDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Not fatal — push notifications are enhancement, not core
        print("[Push] Failed to register: \(error.localizedDescription)")
    }
}
