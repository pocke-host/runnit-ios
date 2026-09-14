import SwiftUI
import RevenueCat

@main
struct RunnitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = AuthService.shared
    @StateObject private var push = PushNotificationService.shared
    @StateObject private var purchases = PurchaseService.shared
    @StateObject private var coros = CorosService.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let rcKey = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String ?? ""
        PurchaseService.configure(apiKey: rcKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(purchases)
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
                        Task {
                            await push.requestPermission()
                            if let userId = auth.currentUser.map({ String($0.id) }) {
                                await purchases.login(userId: userId)
                            }
                        }
                    } else {
                        Task { await purchases.logout() }
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active && auth.isLoggedIn {
                        Task {
                            try? await StravaService.shared.fetchStatus()
                            await CorosService.shared.fetchStatus()
                            await purchases.refreshCustomerInfo()
                        }
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
