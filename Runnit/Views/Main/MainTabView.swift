import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showCreateSheet = false
    @State private var createTarget: CreateTarget?

    enum CreateTarget: Identifiable {
        case story, moment
        var id: Self { self }
    }

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

            EventsView()
                .tabItem { Label("Events", systemImage: "calendar.badge.clock") }
                .tag(3)

            ClubDiscoveryView()
                .tabItem { Label("Clubs", systemImage: "person.3") }
                .tag(4)

            PlansView()
                .tabItem { Label("Plans", systemImage: "calendar") }
                .tag(5)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(6)
        }
        .tint(.black)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        .overlay(alignment: .bottomTrailing) {
            ComposeButton { showCreateSheet = true }
                .padding(.trailing, 20)
                .padding(.bottom, 90)
        }
        .confirmationDialog("Create", isPresented: $showCreateSheet) {
            Button("New Story") { createTarget = .story }
            Button("New Moment") { createTarget = .moment }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $createTarget) { target in
            switch target {
            case .story:  CreateStoryView()
            case .moment: CreateMomentView()
            }
        }
    }
}

// MARK: - Compose FAB

private struct ComposeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.black)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
