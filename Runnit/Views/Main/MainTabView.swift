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
            TrainingTabView()
                .tabItem { Label("Home", systemImage: "square.grid.2x2.fill") }
                .tag(0)

            FeedView(onRecord: { selectedTab = 2 })
                .tabItem { Label("Feed", systemImage: "rectangle.stack.fill") }
                .tag(1)

            TrackView()
                .tabItem { Label("Track", systemImage: "record.circle") }
                .tag(2)

            NativeCalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
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
        .overlay(alignment: .bottom) {
            Button {
                selectedTab = 2
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(RunnitTheme.signal)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(RunnitTheme.canvas, lineWidth: 3))
                    .shadow(color: RunnitTheme.ink.opacity(0.28), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Track activity")
            .offset(y: -24)
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
    @EnvironmentObject private var auth: AuthService
    @StateObject private var activityService = ActivityService.shared
    @StateObject private var integrationService = IntegrationService.shared
    @State private var weeklySummary: WeeklyExerciseSummary?
    @State private var weeklySummaryFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    homeHero
                    weeklyExerciseCard
                    dailyFocus
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
                        subtitle: "Find your next start line and keep race history together.",
                        icon: "flag.checkered",
                        tint: RunnitTheme.yellow
                    ) {
                        NativeRacesView()
                    }

                    TrainingHubLink(
                        title: "Training folders",
                        subtitle: "Group every workout around a race or season.",
                        icon: "folder",
                        tint: RunnitTheme.yellow
                    ) {
                        TrainingFoldersView()
                    }

                    TrainingHubLink(
                        title: "Strength journal",
                        subtitle: "Track volume, progress, and personal records.",
                        icon: "figure.strengthtraining.traditional",
                        tint: RunnitTheme.ink
                    ) {
                        StrengthJournalView()
                    }

                    TrainingHubLink(
                        title: "Multisport days",
                        subtitle: "Combine swim, bike, run, and strength activities.",
                        icon: "figure.mixed.cardio",
                        tint: RunnitTheme.signal
                    ) {
                        MultisportView()
                    }

                    TrainingHubLink(
                        title: "Run clubs",
                        subtitle: "Find the people you want to run with.",
                        icon: "person.3",
                        tint: RunnitTheme.ink
                    ) {
                        ClubDiscoveryView()
                    }

                    TrainingHubLink(
                        title: "Find athletes",
                        subtitle: "Discover people who move like you.",
                        icon: "person.2",
                        tint: RunnitTheme.signal
                    ) {
                        DiscoverView()
                    }
                }
                .padding(20)
            }
            .background(RunnitTheme.canvas)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .task {
                do {
                    async let activities: Void = activityService.fetchMyActivities()
                    async let summary = activityService.fetchWeeklySummary()
                    async let integrations: Void = integrationService.refresh()
                    _ = try await activities
                    weeklySummary = try await summary
                    _ = await integrations
                } catch {
                    weeklySummaryFailed = true
                }
            }
        }
    }

    private var weeklyExerciseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                RunnitSectionLabel(text: "THIS WEEK")
                Spacer()
                if let summary = weeklySummary {
                    Text("\(summary.activityCount) ACTIVITIES")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(RunnitTheme.muted)
                }
            }
            if let summary = weeklySummary {
                HStack(alignment: .bottom, spacing: 12) {
                    Text(summary.formattedTotal)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(RunnitTheme.ink)
                    Text("total exercise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RunnitTheme.muted)
                        .padding(.bottom, 5)
                }
                if let change = summary.changePercent, change != 0 {
                    Text("\(change > 0 ? "↑" : "↓") \(abs(change))% vs last week")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(change > 0 ? RunnitTheme.signal : RunnitTheme.muted)
                }
                if (summary.plannedCount ?? 0) > 0 {
                    Text("Planned \(shortDuration((summary.plannedDurationMinutes ?? 0) * 60)) · Completed \(shortDuration((summary.completedPlannedDurationMinutes ?? 0) * 60))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(RunnitTheme.muted)
                }
                if let freshness = integrationFreshnessLabel {
                    Text(freshness)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(RunnitTheme.muted)
                }
                HStack(spacing: 4) {
                    ForEach(summary.daily) { day in
                        VStack(spacing: 5) {
                            GeometryReader { proxy in
                                let maxSeconds = max(summary.daily.map(\.durationSeconds).max() ?? 1, 1)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(day.date == todayKey ? RunnitTheme.yellow : day.durationSeconds > 0 ? RunnitTheme.signal : RunnitTheme.rule)
                                    .frame(height: max(6, proxy.size.height * CGFloat(day.durationSeconds) / CGFloat(maxSeconds)))
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                            .frame(height: 42)
                            Text(String(day.date.suffix(2)))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(RunnitTheme.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                if !summary.bySport.isEmpty {
                    Text(summary.bySport.map { "\($0.sport.capitalized) \(shortDuration($0.durationSeconds))" }.joined(separator: "  ·  "))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RunnitTheme.muted)
                        .lineLimit(2)
                }
                NavigationLink("View history →", destination: FeedView())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(RunnitTheme.signal)
            } else if weeklySummaryFailed {
                Text("We couldn’t load this week’s total. Pull to refresh or check your connections.")
                    .font(.system(size: 13))
                    .foregroundStyle(RunnitTheme.muted)
            } else {
                ProgressView().tint(RunnitTheme.signal)
            }
        }
        .padding(18)
        .background(Color.white)
        .overlay(Rectangle().stroke(RunnitTheme.rule))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(weeklySummary.map { "This week, \($0.formattedTotal) total exercise across \($0.activityCount) activities" } ?? "Loading this week’s exercise total")
    }

    private func shortDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private var integrationFreshnessLabel: String? {
        let connected = integrationService.statuses.values.filter { $0.connected }
        guard !connected.isEmpty else { return nil }
        return connected.contains(where: { $0.lastSync == nil || $0.needsReconnect == true })
            ? "A connected source needs a sync"
            : "Connected sources up to date"
    }

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var homeHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(todayLine.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(RunnitTheme.yellow.opacity(0.8))
            Text("\(greeting),\n\(firstName.uppercased()).")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 0) {
                HomeStat(label: "DISTANCE", value: distanceText)
                HomeStat(label: "ACTIVITIES", value: "\(activityService.myActivities.count)")
                HomeStat(label: "STREAK", value: "—")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RunnitTheme.ink)
    }

    private var dailyFocus: some View {
        VStack(alignment: .leading, spacing: 12) {
            RunnitSectionLabel(text: "YOUR DAY IN TRAINING")
            Text(dailyFocusTitle)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(RunnitTheme.ink)
            Text(dailyFocusDescription)
                .font(.system(size: 14))
                .foregroundStyle(RunnitTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                NavigationLink(destination: dailyPrimaryDestination) {
                    Text(dailyFocusActionLabel)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(RunnitTheme.signal)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                NavigationLink(destination: PlansView()) {
                    Text("PLANS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .frame(width: 72, height: 44)
                        .foregroundStyle(RunnitTheme.signal)
                        .overlay(Rectangle().stroke(RunnitTheme.signal))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color.white)
        .overlay(Rectangle().stroke(RunnitTheme.rule))
    }

    @ViewBuilder
    private var dailyPrimaryDestination: some View {
        if integrationService.statuses.values.contains(where: { $0.needsReconnect == true }) {
            IntegrationCenterView()
        } else if (weeklySummary?.activityCount ?? 0) > 0 {
            FeedView()
        } else {
            TrackView()
        }
    }

    private var dailyFocusTitle: String {
        if integrationService.statuses.values.contains(where: { $0.needsReconnect == true }) { return "Keep your training connected." }
        if (weeklySummary?.activityCount ?? 0) > 0 { return "See how your week is moving." }
        return "Make your first move."
    }

    private var dailyFocusDescription: String {
        if integrationService.statuses.values.contains(where: { $0.needsReconnect == true }) { return "One of your connected sources needs attention before your dashboard can stay current." }
        if (weeklySummary?.activityCount ?? 0) > 0 { return "Your latest training is in. Review the week, then decide what comes next." }
        return "Record one activity and your dashboard will start shaping itself around your training."
    }

    private var dailyFocusActionLabel: String {
        if integrationService.statuses.values.contains(where: { $0.needsReconnect == true }) { return "RECONNECT A DEVICE →" }
        if (weeklySummary?.activityCount ?? 0) > 0 { return "REVIEW YOUR PROGRESS →" }
        return "RECORD TODAY’S ACTIVITY →"
    }

    private var firstName: String {
        auth.currentUser?.displayName.split(separator: " ").first.map(String.init) ?? "Athlete"
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var todayLine: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var distanceText: String {
        let meters = activityService.myActivities.compactMap(\.distanceMeters).reduce(0, +)
        return String(format: "%.1f km", meters / 1000)
    }
}

private struct HomeStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(RunnitTheme.canvas.opacity(0.5))
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
