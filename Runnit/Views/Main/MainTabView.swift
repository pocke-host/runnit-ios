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
                .tabItem { Label("Record", systemImage: "record.circle") }
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

            let itemAppearance = UITabBarItemAppearance()
            itemAppearance.normal.iconColor = UIColor(RunnitTheme.muted)
            itemAppearance.normal.titleTextAttributes = [
                .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .bold),
                .foregroundColor: UIColor(RunnitTheme.muted)
            ]
            itemAppearance.selected.iconColor = UIColor(RunnitTheme.signal)
            itemAppearance.selected.titleTextAttributes = [
                .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .bold),
                .foregroundColor: UIColor(RunnitTheme.signal)
            ]
            appearance.stackedLayoutAppearance = itemAppearance
            appearance.inlineLayoutAppearance = itemAppearance
            appearance.compactInlineLayoutAppearance = itemAppearance

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
            .accessibilityLabel("Record activity")
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
    @State private var monthlySummary: MonthlyExerciseSummary?
    @State private var todayWellness: TodayWellnessSummary?
    @State private var trainingLoad: TrainingLoadSummary?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    homeHero
                    weeklyExerciseCard
                    monthlyRecapCard
                    trainingStatusCard
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
                        title: "Training goals",
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
                        title: "Challenges",
                        subtitle: "Find a shared goal, invite your crew, and celebrate the finish.",
                        icon: "trophy",
                        tint: RunnitTheme.yellow
                    ) {
                        NativeChallengesView()
                    }

                    TrainingHubLink(
                        title: "Find athletes",
                        subtitle: "Discover people who move like you.",
                        icon: "person.2",
                        tint: RunnitTheme.signal
                    ) {
                        DiscoverView()
                    }

                    TrainingHubLink(
                        title: "Friend progress",
                        subtitle: "See the people you follow keeping momentum.",
                        icon: "chart.line.uptrend.xyaxis",
                        tint: RunnitTheme.signal
                    ) {
                        FriendProgressView()
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
                    async let monthly: MonthlyExerciseSummary? = try? activityService.fetchMonthlySummary()
                    async let integrations: Void = integrationService.refresh()
                    async let wellness: TodayWellnessSummary? = try? activityService.fetchTodayWellness()
                    async let load: TrainingLoadSummary? = try? activityService.fetchTrainingLoad()
                    _ = try await activities
                    weeklySummary = try await summary
                    monthlySummary = await monthly
                    todayWellness = await wellness
                    trainingLoad = await load
                    _ = await integrations
                } catch {
                    weeklySummaryFailed = true
                }
            }
        }
    }

    private var trainingStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    RunnitSectionLabel(text: "TRAINING STATUS")
                    Text("The numbers behind your next move.")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(integrationFreshnessLabel ?? "RUNNIT DATA")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(RunnitTheme.canvas.opacity(0.55))
                    .multilineTextAlignment(.trailing)
            }

            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 1) {
                trainingStatusMetric(label: "RECOVERY", value: recoveryStatusValue, detail: recoveryStatusDetail)
                trainingStatusMetric(label: "TRAINING LOAD", value: loadStatusValue, detail: loadStatusDetail)
                trainingStatusMetric(label: "THIS WEEK", value: weeklySummary?.formattedTotal ?? "—", detail: weeklyStatusDetail)
                trainingStatusMetric(label: "PLANNED", value: plannedStatusValue, detail: plannedStatusDetail)
            }
            .padding(.vertical, 1)
            .background(RunnitTheme.canvas.opacity(0.14))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TRAINING INSIGHTS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(RunnitTheme.yellow)
                    Spacer()
                    Text("BACKEND LOAD")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(RunnitTheme.canvas.opacity(0.42))
                }
                if let load = trainingLoad, load.hasEnoughData == true {
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 10) {
                        trainingInsightMetric(label: "FITNESS", value: loadValue(load.ctl), detail: "42D")
                        trainingInsightMetric(label: "FATIGUE", value: loadValue(load.atl), detail: "7D")
                        trainingInsightMetric(label: "FORM", value: signedLoadValue(load.tsb), detail: "BALANCE")
                        trainingInsightMetric(label: "ACWR", value: decimalLoadValue(load.acwr), detail: "RATIO")
                    }
                    Text(nativeTrainingInsightSummary(for: load))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(RunnitTheme.canvas.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Log a few activities and RUNNIT will build a reliable training-load baseline.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(RunnitTheme.canvas.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 5) {
                Text("RUNNIT READ")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(RunnitTheme.yellow)
                Text(trainingRecommendationTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(trainingRecommendationMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(RunnitTheme.canvas.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLink("SEE YOUR WEEK →", destination: FeedView())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(RunnitTheme.yellow)
        }
        .padding(18)
        .background(RunnitTheme.ink)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Training status. \(trainingRecommendationTitle) \(trainingRecommendationMessage)")
    }

    @ViewBuilder
    private func trainingStatusMetric(label: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(RunnitTheme.canvas.opacity(0.5))
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(RunnitTheme.canvas.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(RunnitTheme.ink)
    }

    @ViewBuilder
    private func trainingInsightMetric(label: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(RunnitTheme.canvas.opacity(0.48))
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(RunnitTheme.canvas.opacity(0.42))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(Int(value.rounded()))
    }

    private func signedLoadValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        let rounded = Int(value.rounded())
        return "\(rounded > 0 ? "+" : "")\(rounded)"
    }

    private func decimalLoadValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f", value)
    }

    private func nativeTrainingInsightSummary(for load: TrainingLoadSummary) -> String {
        switch load.riskLabel {
        case "HIGH_RISK": return "Your short-term load is rising faster than your baseline. Keep the next session easy."
        case "DETRAINING": return "Your recent load is light. Add easy, repeatable sessions before chasing intensity."
        case "OPTIMAL": return "Your recent training is in a manageable range. Keep the week consistent."
        default: return "Keep logging sessions so RUNNIT can make this read more personal."
        }
    }

    private var recoveryStatusValue: String {
        guard let score = todayWellness?.recoveryScore else { return "—" }
        return "\(score)/100"
    }

    private var recoveryStatusDetail: String {
        guard let wellness = todayWellness else { return "Connect a wearable" }
        return wellness.source ?? "Wellness signal"
    }

    private var loadStatusValue: String {
        guard let load = trainingLoad, load.hasEnoughData != false else { return "BASELINE" }
        switch load.riskLabel {
        case "HIGH_RISK": return "HIGH RISK"
        case "DETRAINING": return "LOW LOAD"
        case "OPTIMAL": return "ON TRACK"
        default: return "—"
        }
    }

    private var loadStatusDetail: String {
        guard let tsb = trainingLoad?.tsb else { return "Need 3 activities" }
        return "Form \(tsb > 0 ? "+" : "")\(String(format: "%.1f", tsb))"
    }

    private var weeklyStatusDetail: String {
        let count = weeklySummary?.activityCount ?? 0
        return "\(count) session\(count == 1 ? "" : "s")"
    }

    private var plannedStatusValue: String {
        guard let summary = weeklySummary, let planned = summary.plannedDurationMinutes, planned > 0 else { return "—" }
        return "\(summary.completedPlannedDurationMinutes ?? 0)m"
    }

    private var plannedStatusDetail: String {
        guard let planned = weeklySummary?.plannedDurationMinutes, planned > 0 else { return "Choose a plan" }
        return "of \(planned)m planned"
    }

    private var trainingRecommendationTitle: String {
        if integrationService.statuses.values.contains(where: { $0.needsReconnect == true }) { return "Reconnect before you rely on the numbers." }
        if let recovery = todayWellness?.recoveryScore, recovery < 34 { return "Keep today easy." }
        if trainingLoad?.riskLabel == "HIGH_RISK" { return "Keep today controlled." }
        if let recovery = todayWellness?.recoveryScore, recovery >= 67 { return "Good day to build." }
        if (weeklySummary?.activityCount ?? 0) > 0 { return "Keep the week consistent." }
        return "Build your baseline."
    }

    private var trainingRecommendationMessage: String {
        if integrationService.statuses.values.contains(where: { $0.needsReconnect == true }) { return "A connected source needs attention, so today’s status may be incomplete." }
        if let recovery = todayWellness?.recoveryScore, recovery < 34 { return "Your recovery signal is low. Favor lighter movement or extra recovery before adding intensity." }
        if trainingLoad?.riskLabel == "HIGH_RISK" { return "Your recent load is elevated. Favor an easy session or recovery before adding more intensity." }
        if let recovery = todayWellness?.recoveryScore, recovery >= 67 { return "Your recovery signal supports the planned session. Stay aligned with your training block." }
        if (weeklySummary?.activityCount ?? 0) > 0 { return "Your recent training is in. Review the week, then decide what supports your goal next." }
        return "Record an activity or connect a device so RUNNIT can make the next recommendation more personal."
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

    private var monthlyRecapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    RunnitSectionLabel(text: "MONTHLY RECAP")
                    Text(monthlySummary.map { "\($0.monthLabel) vs \($0.previousMonthLabel)" } ?? "A whole lot of insight")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(RunnitTheme.ink)
                }
                Spacer()
                Text("WHOLE LOT\nOF INSIGHT")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RunnitTheme.ink)
                    .padding(7)
                    .background(RunnitTheme.yellow)
            }

            if let summary = monthlySummary {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("TOTAL TRAINING TIME")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(RunnitTheme.muted)
                        Text(summary.formattedTotal)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(RunnitTheme.ink)
                    }
                    Spacer()
                    Text(monthlyChangeLabel(summary.changePercent))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle((summary.changePercent ?? 0) < 0 ? RunnitTheme.coral : RunnitTheme.signal)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 14)
                .overlay(alignment: .top) { Rectangle().fill(RunnitTheme.rule).frame(height: 1) }
                .overlay(alignment: .bottom) { Rectangle().fill(RunnitTheme.rule).frame(height: 1) }

                HStack(spacing: 0) {
                    monthlyMetric(label: "SESSIONS", value: "\(summary.activityCount)", detail: monthlyChangeLabel(summary.activityChangePercent))
                    monthlyMetric(label: "DISTANCE", value: shortDistance(summary.totalDistanceMeters), detail: monthlyChangeLabel(summary.distanceChangePercent))
                    monthlyMetric(label: "ACTIVE DAYS", value: "\(summary.activeDays)", detail: monthlyChangeLabel(summary.activeDaysChangePercent))
                }

                if !summary.bySport.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WHERE YOUR TIME WENT")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(RunnitTheme.muted)
                        Text(summary.bySport.prefix(4).map { "\($0.sport.capitalized) \(shortDuration($0.durationSeconds))" }.joined(separator: "  ·  "))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(RunnitTheme.ink)
                            .lineLimit(2)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("RUNNIT READ")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(RunnitTheme.signal)
                    Text(monthlyInsightTitle(for: summary))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(RunnitTheme.ink)
                    Text(monthlyInsightMessage(for: summary))
                        .font(.system(size: 12))
                        .foregroundStyle(RunnitTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(RunnitTheme.canvas)
            } else {
                Text("Log a few sessions and RUNNIT will compare your completed months here.")
                    .font(.system(size: 13))
                    .foregroundStyle(RunnitTheme.muted)
            }
        }
        .padding(18)
        .background(Color.white)
        .overlay(Rectangle().stroke(RunnitTheme.rule))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(monthlySummary.map { "Monthly recap. \($0.monthLabel) compared with \($0.previousMonthLabel). \($0.formattedTotal) across \($0.activityCount) sessions." } ?? "Monthly recap loading")
    }

    @ViewBuilder
    private func monthlyMetric(label: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(RunnitTheme.muted)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(RunnitTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(RunnitTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 9)
        .overlay(alignment: .trailing) { Rectangle().fill(RunnitTheme.rule).frame(width: 1) }
    }

    private func monthlyChangeLabel(_ percent: Int?) -> String {
        guard let percent else { return "No prior data" }
        if percent == 0 { return "Flat vs prior" }
        return "\(percent > 0 ? "↑" : "↓") \(abs(percent))% vs prior"
    }

    private func shortDistance(_ meters: Int) -> String {
        let miles = Double(meters) / 1609.344
        if miles >= 100 { return "\(Int(miles.rounded())) mi" }
        return String(format: "%.1f mi", miles)
    }

    private func monthlyInsightTitle(for summary: MonthlyExerciseSummary) -> String {
        if summary.activityCount == 0 { return "A clean slate." }
        if (summary.changePercent ?? 0) >= 10 { return "You built momentum." }
        if (summary.changePercent ?? 0) <= -10 { return "A lighter month can be useful." }
        return "You kept the work steady."
    }

    private func monthlyInsightMessage(for summary: MonthlyExerciseSummary) -> String {
        if summary.activityCount == 0 { return "Start with one simple workout and let the next month take shape." }
        let sport = summary.bySport.first?.sport.lowercased() ?? "training"
        if (summary.changePercent ?? 0) >= 10 { return "You spent more time training than the month before, led by \(sport). Keep the rhythm sustainable." }
        if (summary.changePercent ?? 0) <= -10 { return "Your training time came down from the month before. Use the context, then choose the next block deliberately." }
        return "Your month stayed consistent, with \(sport) taking the biggest share of your training time."
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

private struct FriendProgressView: View {
    @StateObject private var service = TrainingHubService.shared
    @State private var friends: [FriendProgress] = []
    @State private var error: String?

    var body: some View {
        Group {
            if friends.isEmpty && error == nil { ContentUnavailableView("No friend progress yet", systemImage: "person.2", description: Text("Follow athletes to see their weekly momentum here.")) }
            else if let error { ContentUnavailableView("Couldn’t load progress", systemImage: "wifi.exclamationmark", description: Text(error)) }
            else { List(friends) { friend in progressRow(friend) }.listStyle(.plain).scrollContentBackground(.hidden) }
        }
        .background(RunnitTheme.canvas)
        .navigationTitle("Friend progress")
        .task { await load() }
        .refreshable { await load() }
    }

    private func progressRow(_ friend: FriendProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(friend.displayName).font(.headline); Spacer(); Text("\(friend.activityCount) workouts").font(.caption).foregroundStyle(RunnitTheme.muted) }
            HStack(spacing: 16) { Label("\(friend.durationMinutes) min", systemImage: "clock"); if friend.distanceMeters > 0 { Label(String(format: "%.1f km", Double(friend.distanceMeters) / 1000), systemImage: "figure.run") } }
                .font(.caption).foregroundStyle(RunnitTheme.muted)
        }.padding(16).background(Color.white).overlay(Rectangle().stroke(RunnitTheme.rule))
    }

    private func load() async { do { error = nil; friends = try await service.fetchFriendProgress() } catch let requestError { friends = []; error = requestError.localizedDescription } }
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

private struct NativeChallenge: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let sport: String?
    let imageUrl: String?
    let endDate: Date?
    let prize: String?
    let participantCount: Int
}

@MainActor
private final class NativeChallengeService: ObservableObject {
    @Published var challenges: [NativeChallenge] = []
    @Published var enteredIds = Set<Int>()
    private let api = APIClient.shared

    func load() async throws {
        challenges = try await api.request("/challenges")
        let mine: [NativeChallenge] = try await api.request("/challenges/my")
        enteredIds = Set(mine.map(\.id))
    }

    func toggle(_ challenge: NativeChallenge) async throws {
        if enteredIds.contains(challenge.id) {
            try await api.requestVoid("/challenges/\(challenge.id)/leave", method: "DELETE")
            enteredIds.remove(challenge.id)
        } else {
            try await api.requestVoid("/challenges/\(challenge.id)/enter", method: "POST")
            enteredIds.insert(challenge.id)
        }
    }
}

private struct NativeChallengesView: View {
    @StateObject private var service = NativeChallengeService()
    @State private var errorMessage: String?
    @State private var loadingId: Int?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if service.challenges.isEmpty {
                    ContentUnavailableView("No challenges yet", systemImage: "trophy", description: Text("New community challenges will show up here."))
                } else {
                    ForEach(service.challenges) { challenge in
                        challengeCard(challenge)
                    }
                }
            }
            .padding(20)
        }
        .background(RunnitTheme.canvas)
        .navigationTitle("Challenges")
        .navigationBarTitleDisplayMode(.large)
        .task {
            do { try await service.load() } catch { errorMessage = error.localizedDescription }
        }
        .refreshable {
            do { try await service.load() } catch { errorMessage = error.localizedDescription }
        }
        .alert("Couldn’t update challenge", isPresented: .init(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func challengeCard(_ challenge: NativeChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.name).font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(RunnitTheme.ink)
                    if let sport = challenge.sport { Text(sport.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(RunnitTheme.signal) }
                }
                Spacer()
                ShareLink(item: "Join me in the Runnit challenge \"\(challenge.name)\": https://runnit.live/challenges/\(challenge.id)") {
                    Image(systemName: "square.and.arrow.up").foregroundStyle(RunnitTheme.signal)
                }
                .accessibilityLabel("Share \(challenge.name) challenge")
            }
            if let description = challenge.description { Text(description).font(.system(size: 13)).foregroundStyle(RunnitTheme.muted) }
            HStack {
                Label("\(challenge.participantCount) joined", systemImage: "person.2")
                if let endDate = challenge.endDate { Label("Ends \(endDate.formatted(.dateTime.month(.abbreviated).day()))", systemImage: "clock") }
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(RunnitTheme.muted)
            Button {
                loadingId = challenge.id
                Task {
                    do { try await service.toggle(challenge) } catch { errorMessage = error.localizedDescription }
                    loadingId = nil
                }
            } label: {
                Group {
                    if loadingId == challenge.id { ProgressView().frame(maxWidth: .infinity) }
                    else { Text(service.enteredIds.contains(challenge.id) ? "LEAVE CHALLENGE" : "JOIN CHALLENGE") .frame(maxWidth: .infinity) }
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced)).frame(height: 42)
                .background(service.enteredIds.contains(challenge.id) ? RunnitTheme.canvas : RunnitTheme.signal)
                .foregroundStyle(service.enteredIds.contains(challenge.id) ? RunnitTheme.ink : .white)
                .overlay(Rectangle().stroke(RunnitTheme.rule))
            }
            .buttonStyle(.plain)
            .disabled(loadingId != nil)
        }
        .padding(18).background(Color.white).overlay(Rectangle().stroke(RunnitTheme.rule))
    }
}
