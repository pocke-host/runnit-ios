import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem { Label("Feed", systemImage: "house") }
                .tag(0)

            DiscoverView()
                .tabItem { Label("Discover", systemImage: "magnifyingglass") }
                .tag(1)

            TrackView()
                .tabItem { Label("Track", systemImage: "record.circle") }
                .tag(2)

            PlansView()
                .tabItem { Label("Plans", systemImage: "calendar") }
                .tag(3)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(4)
        }
        .tint(.black)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
