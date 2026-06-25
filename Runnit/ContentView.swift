import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthService

    /// True when the user is logged in but hasn't finished onboarding yet.
    private var needsOnboarding: Bool {
        auth.isLoggedIn && auth.currentUser?.onboardingComplete == false
    }

    var body: some View {
        Group {
            if auth.isLoading {
                SplashView()
            } else if auth.isLoggedIn {
                MainTabView()
                    // Present onboarding as a full-screen cover that dismisses itself
                    // once the POST /auth/onboarding call marks onboardingComplete = true.
                    .fullScreenCover(isPresented: .constant(needsOnboarding)) {
                        OnboardingView()
                            .environmentObject(auth)
                    }
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.isLoggedIn)
    }
}
