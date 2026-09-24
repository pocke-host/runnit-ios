import SwiftUI

struct IntegrationCenterView: View {
    @StateObject private var service = IntegrationService.shared
    @Environment(\.openURL) private var openURL
    @State private var message: String?
    var body: some View {
        List {
            Section { Text("Keep your training history together. Runnit will show the last sync and tell you when an account needs attention.").font(.subheadline).foregroundStyle(RunnitTheme.muted).padding(.vertical, 4) }
            Section("CONNECTED SERVICES") {
                providerRow("COROS", key: "coros", icon: "watch.analog")
                providerRow("WHOOP", key: "whoop", icon: "heart.fill")
                providerRow("Oura Ring", key: "oura", icon: "circle.dotted")
                providerRow("Fitbit", key: "fitbit", icon: "figure.run")
                providerRow("Spotify", key: "spotify", icon: "music.note")
                providerRow("RunSignup", key: "runsignup", icon: "flag.checkered")
                HealthStatusRow()
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(RunnitTheme.canvas)
        .navigationTitle("Integrations")
        .task { await service.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .oauthCallbackCompleted)) { note in
            let provider = note.userInfo?["provider"] as? String ?? "provider"
            message = "\(provider.capitalized) connected."
            Task { await service.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .oauthCallbackFailed)) { note in
            let reason = note.userInfo?["reason"] as? String ?? "The provider did not complete authorization."
            message = "Connection failed: \(reason)"
        }
        .alert("Integrations", isPresented: .init(get: { message != nil }, set: { _ in message = nil })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
    }

    @ViewBuilder private func providerRow(_ name: String, key: String, icon: String) -> some View {
        let status = service.statuses[key]
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 28).foregroundStyle(RunnitTheme.signal)
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.headline)
                Text(statusLine(status)).font(.caption).foregroundStyle(status?.connected == true ? .green : RunnitTheme.muted)
                Text(status?.connected == true ? "Permission active · Runnit can sync this source" : "Permission needed · connect to import training")
                    .font(.caption2).foregroundStyle(status?.connected == true ? RunnitTheme.muted : .orange)
                if let sync = status?.lastSync { Text("Last sync \(sync)").font(.caption2).foregroundStyle(RunnitTheme.muted) }
                if key == "spotify", status?.connected == true { NavigationLink("Listening summary") { SpotifyListeningSummaryView() }.font(.caption) }
            }
            Spacer()
            if status?.needsReconnect == true { Text("Reconnect").font(.caption.bold()).foregroundStyle(.orange) }
            Button(status?.connected == true ? "Sync" : "Connect") {
                Task {
                    do {
                        if status?.connected == true && key != "spotify" && key != "runsignup" { message = "Imported \(try await service.sync(provider: key)) items." }
                        else { openURL(try await service.connectURL(provider: key)) }
                    } catch { message = error.localizedDescription }
                }
            }.buttonStyle(.borderedProminent).tint(RunnitTheme.signal)
        }.accessibilityElement(children: .combine).accessibilityLabel("\(name), \(statusLine(status))")
    }
    private func statusLine(_ status: IntegrationStatus?) -> String { guard let status else { return "Checking connection…" }; return status.needsReconnect == true ? "Needs reconnect" : status.connected ? "Connected" : "Not connected" }
}

private struct SpotifyListeningSummaryView: View {
    @StateObject private var service = TrainingHubService.shared
    @State private var period = "week"
    @State private var summary: SpotifyListeningSummary?
    @State private var status: String?
    @State private var loading = false

    var body: some View {
        List {
            Section { Picker("Period", selection: $period) { Text("This week").tag("week"); Text("This month").tag("month") }.pickerStyle(.segmented) }
            if loading { Section { ProgressView("Loading listening summary…") } }
            else if let summary {
                Section("WORKOUT SOUNDTRACK") {
                    LabeledContent("Workout time", value: "\(summary.workoutMinutes) min")
                    LabeledContent("Activities with music", value: "\(summary.activitiesWithListening)")
                    LabeledContent("Unique tracks", value: "\(summary.uniqueTracks)")
                }
                Section("TOP TRACKS") { ForEach(summary.topTracks) { track in HStack { Text(track.track); Spacer(); Text("\(track.plays)").foregroundStyle(RunnitTheme.muted) } } }
                Section("TOP ARTISTS") { ForEach(summary.topArtists) { artist in HStack { Text(artist.artist); Spacer(); Text("\(artist.plays)").foregroundStyle(RunnitTheme.muted) } } }
                Section { Button("Create \(period) Spotify playlist") { Task { await createPlaylist() } }.disabled(loading) }
            } else { ContentUnavailableView("No soundtrack yet", systemImage: "music.note", description: Text("Attach a Spotify track to a workout, then your summary will appear here.")) }
            if let status { Section { Text(status).font(.caption).foregroundStyle(RunnitTheme.muted) } }
        }
        .navigationTitle("Listening summary")
        .task { await load() }
        .onChange(of: period) { _, _ in Task { await load() } }
    }

    private func load() async {
        loading = true; defer { loading = false }
        do { summary = try await service.fetchSpotifySummary(period: period); status = nil }
        catch { summary = nil; status = error.localizedDescription }
    }

    private func createPlaylist() async {
        loading = true; defer { loading = false }
        do { let result = try await service.createSpotifyPlaylist(period: period); status = "Created \(result.name ?? "your Runnit playlist") in Spotify." }
        catch { status = error.localizedDescription }
    }
}

private struct HealthStatusRow: View {
    @StateObject private var service = HealthKitService.shared
    @State private var message: String?
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.text.square").frame(width: 28).foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 3) { Text("Apple Health").font(.headline); Text(service.status?.connected == true ? "Connected" : "Not connected").font(.caption).foregroundStyle(service.status?.connected == true ? .green : RunnitTheme.muted) }
            Spacer()
            Button(service.status?.connected == true ? "Sync" : "Connect") { Task { do { message = "Imported \(try await (service.status?.connected == true ? service.syncRecentWorkouts() : service.connectAndSync())) workouts." } catch { message = error.localizedDescription } } }.buttonStyle(.borderedProminent).tint(RunnitTheme.signal)
        }.task { await service.fetchStatus() }.alert("Apple Health", isPresented: .init(get: { message != nil }, set: { _ in message = nil })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
    }
}
