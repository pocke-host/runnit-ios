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

            TrainingTabView()
                .tabItem { Label("Training", systemImage: "calendar") }
                .tag(3)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(4)
        }
        .tint(RunnitTheme.signal)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(RunnitTheme.canvas)
            appearance.shadowColor = UIColor(RunnitTheme.rule)
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

// MARK: - Training hub

private struct TrainingTabView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        RunnitSectionLabel(text: "YOUR TRAINING")
                        Text("Build the block.")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(RunnitTheme.ink)
                        Text("Plans, races, and your running crew in one place.")
                            .font(.system(size: 15))
                            .foregroundStyle(RunnitTheme.muted)
                    }

                    TrainingHubLink(
                        title: "Training plans",
                        subtitle: "Follow your next workout and stay on track.",
                        icon: "calendar",
                        tint: RunnitTheme.signal
                    ) {
                        PlansView()
                    }

                    TrainingHubLink(
                        title: "Races & events",
                        subtitle: "Find your next start line and manage RSVPs.",
                        icon: "flag.checkered",
                        tint: RunnitTheme.yellow
                    ) {
                        EventsView()
                    }

                    TrainingHubLink(
                        title: "Run clubs",
                        subtitle: "Find the people you want to run with.",
                        icon: "person.3",
                        tint: RunnitTheme.ink
                    ) {
                        ClubDiscoveryView()
                    }
                }
                .padding(20)
            }
            .background(RunnitTheme.canvas)
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct TrainingHubLink<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint == RunnitTheme.yellow ? RunnitTheme.ink : .white)
                    .frame(width: 46, height: 46)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: RunnitTheme.radius))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(RunnitTheme.ink)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(RunnitTheme.muted)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(RunnitTheme.signal)
            }
            .padding(16)
            .background(Color.white)
            .overlay(Rectangle().stroke(RunnitTheme.rule))
        }
        .buttonStyle(.plain)
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
                .background(RunnitTheme.signal)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
