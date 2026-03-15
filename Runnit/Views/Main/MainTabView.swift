import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem { Label("Feed", systemImage: "house") }
                .tag(0)

            TrackView()
                .tabItem { Label("Track", systemImage: "record.circle") }
                .tag(1)

            PlansView()
                .tabItem { Label("Plans", systemImage: "calendar") }
                .tag(2)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(3)
        }
        .tint(.black)
        .onAppear {
            // Black tab bar to match web design system
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
