import SwiftUI

@main
struct RunnitApp: App {
    @StateObject private var auth = AuthService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .onOpenURL { url in
                    // Handle deep links: runnit://oauth/strava?code=...
                    DeepLinkHandler.handle(url)
                }
        }
    }
}
