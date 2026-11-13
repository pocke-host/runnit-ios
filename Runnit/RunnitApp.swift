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
        // Register HealthKit's observer as early as possible so Apple Watch
        // workouts can wake the app even when the UI is not open.
        Task { @MainActor in
            HealthKitService.shared.startAutomaticSync()
        }
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
                    HealthKitService.shared.startAutomaticSync()
                    if auth.isLoggedIn {
                        await push.requestPermission()
                        await HealthKitService.shared.fetchStatus()
                        if HealthKitService.shared.status?.connected == true {
                            try? await HealthKitService.shared.syncNewWorkouts()
                        }
                    }
                }
                .onChange(of: auth.isLoggedIn) { _, loggedIn in
                    if loggedIn {
                        Task {
                            await push.requestPermission()
                            HealthKitService.shared.startAutomaticSync()
                            await HealthKitService.shared.fetchStatus()
                            if HealthKitService.shared.status?.connected == true {
                                try? await HealthKitService.shared.syncNewWorkouts()
                            }
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
                            await CorosService.shared.fetchStatus()
                            await purchases.refreshCustomerInfo()
                            HealthKitService.shared.startAutomaticSync()
                            await HealthKitService.shared.fetchStatus()
                            if HealthKitService.shared.status?.connected == true {
                                try? await HealthKitService.shared.syncNewWorkouts()
                            }
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
