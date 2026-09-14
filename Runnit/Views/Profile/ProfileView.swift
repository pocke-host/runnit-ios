import SwiftUI

// MARK: - Archetype response

private struct ArchetypeResponse: Decodable {
    let archetype: String
    let label: String
    let tagline: String
}

// MARK: - ProfileView

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @StateObject private var activityService = ActivityService.shared
    @StateObject private var strava = StravaService.shared
    @StateObject private var coros = CorosService.shared
    @StateObject private var healthKit = HealthKitService.shared
    @State private var showEditProfile = false
    @State private var showLogoutConfirm = false
    @State private var stravaError: String?
    @State private var syncMessage: String?
    @State private var corosError: String?
    @State private var corosSyncMessage: String?
    @State private var healthError: String?
    @State private var healthSyncMessage: String?
    @State private var archetypeResponse: ArchetypeResponse?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let user = auth.currentUser {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 12) {
                            AsyncImage(url: user.avatarURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(RunnitTheme.yellow)
                                    .overlay(Text(user.displayName.prefix(1).uppercased())
                                        .font(.system(size: 32, weight: .black)).foregroundStyle(RunnitTheme.ink))
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())

                            VStack(spacing: 4) {
                                Text(user.displayName)
                                    .font(.system(size: 22, weight: .black))
                                Text("@\(user.user)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(RunnitTheme.muted)
                            }

                            if let bio = user.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.system(size: 14))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(RunnitTheme.muted)
                                    .padding(.horizontal, 32)
                            }

                            HStack(spacing: 8) {
                                if let sport = user.sport {
                                    Label(sport, systemImage: "figure.run")
                                        .font(.system(size: 12))
                                        .foregroundStyle(RunnitTheme.muted)
                                }
                                if let location = user.location {
                                    Label(location, systemImage: "mappin")
                                        .font(.system(size: 12))
                                        .foregroundStyle(RunnitTheme.muted)
                                }
                            }

                            // Archetype badge — only shown for the logged-in user's own profile
                            if let resp = archetypeResponse {
                                VStack(spacing: 6) {
                                    Text(resp.label.uppercased())
                                        .font(.system(size: 11, weight: .black))
                                        .tracking(2)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(Color.white)
                                        .foregroundStyle(RunnitTheme.ink)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))

                                    Text(resp.tagline)
                                        .font(.system(size: 12))
                                        .foregroundStyle(RunnitTheme.yellow)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(RunnitTheme.ink)
                        .foregroundStyle(.white)

                        // Edit profile button
                        Button("Edit Profile") { showEditProfile = true }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .overlay(Rectangle().stroke(RunnitTheme.rule, lineWidth: 1))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RunnitTheme.signal)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        // Recent activities
                        if !activityService.myActivities.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("RECENT ACTIVITIES")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 24)
                                    .padding(.bottom, 12)

                                ForEach(activityService.myActivities.prefix(5)) { activity in
                                    NavigationLink(destination: ActivityDetailView(activityId: activity.id)) {
                                        ActivityCard(activity: activity)
                                            .padding(.horizontal, 20)
                                            .padding(.bottom, 12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Connected Apps
                        VStack(alignment: .leading, spacing: 0) {
                            Divider().padding(.top, 20)

                            Text("CONNECTED APPS")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 12)

                            StravaRow(
                                strava: strava,
                                errorMessage: $stravaError,
                                syncMessage: $syncMessage
                            )
                            .padding(.horizontal, 20)

                            CorosRow(
                                coros: coros,
                                errorMessage: $corosError,
                                syncMessage: $corosSyncMessage
                            )
                            .padding(.horizontal, 20)

                            AppleHealthRow(
                                healthKit: healthKit,
                                errorMessage: $healthError,
                                syncMessage: $healthSyncMessage
                            )
                            .padding(.horizontal, 20)

                            if let msg = syncMessage {
                                Text(msg)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 6)
                            }
                            if let err = stravaError {
                                Text(err)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 6)
                            }
                        }

                        // Settings section
                        VStack(spacing: 0) {
                            Divider().padding(.top, 20)

                            Button(role: .destructive) { showLogoutConfirm = true } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Log Out")
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .foregroundStyle(.red)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .background(RunnitTheme.canvas)
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .confirmationDialog("Log out of Runnit?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Log Out", role: .destructive) { auth.logout() }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                async let _ = activityService.fetchMyActivities()
                async let _ = strava.fetchStatus()
                async let _ = coros.fetchStatus()
                async let _ = healthKit.fetchStatus()
                do {
                    archetypeResponse = try await APIClient.shared.request("/users/me/archetype")
                } catch {
                    // Archetype is non-critical; silently skip if unavailable
                }
            }
        }
    }
}

// MARK: - CorosRow

struct CorosRow: View {
    @ObservedObject var coros: CorosService
    @Binding var errorMessage: String?
    @Binding var syncMessage: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        IntegrationRow(
            icon: "watch.analog",
            iconColor: .orange,
            name: "COROS",
            status: coros.status?.connected == true ? "Connected" : "Not connected",
            connected: coros.status?.connected == true,
            isLoading: coros.isLoading,
            isSyncing: coros.isSyncing,
            connect: connect,
            sync: sync,
            disconnect: disconnect
        )
        if let syncMessage { InlineIntegrationMessage(text: syncMessage, color: .secondary) }
        if let errorMessage { InlineIntegrationMessage(text: errorMessage, color: .red) }
    }

    private func connect() {
        errorMessage = nil
        Task {
            do { openURL(try await coros.connectURL()) }
            catch { errorMessage = "Could not start COROS connection." }
        }
    }
    private func sync() {
        errorMessage = nil
        Task {
            do { syncMessage = "\(try await coros.sync()) activities imported" }
            catch { errorMessage = "COROS sync failed. Try again." }
        }
    }
    private func disconnect() {
        errorMessage = nil
        Task { do { try await coros.disconnect() } catch { errorMessage = "Could not disconnect COROS." } }
    }
}

// MARK: - AppleHealthRow

struct AppleHealthRow: View {
    @ObservedObject var healthKit: HealthKitService
    @Binding var errorMessage: String?
    @Binding var syncMessage: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill").font(.system(size: 18)).foregroundStyle(.red).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Health").font(.system(size: 15, weight: .semibold))
                Text(healthKit.status?.connected == true ? "Connected" : "Not connected")
                    .font(.system(size: 12)).foregroundStyle(healthKit.status?.connected == true ? Color.green : Color(.systemGray))
            }
            Spacer()
            if healthKit.isLoading { ProgressView().frame(width: 60) }
            else if healthKit.status?.connected == true {
                HStack(spacing: 8) {
                    Button {
                        Task { do { syncMessage = "\(try await healthKit.syncRecentWorkouts()) workouts imported" } catch { errorMessage = "Apple Health sync failed. Try again." } }
                    } label: {
                        Text(healthKit.isSyncing ? "Syncing…" : "Sync").font(.system(size: 13, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 6).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.systemGray3)))
                    }.disabled(healthKit.isSyncing)
                    Button("Disconnect", role: .destructive) { Task { do { try await healthKit.disconnect() } catch { errorMessage = "Could not disconnect Apple Health." } } }
                        .font(.system(size: 13, weight: .medium))
                }
            } else {
                Button("Connect") {
                    Task { do { syncMessage = "\(try await healthKit.connectAndSync()) workouts imported" } catch { errorMessage = error.localizedDescription } }
                }.font(.system(size: 13, weight: .semibold)).padding(.horizontal, 14).padding(.vertical, 6).background(.black).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }.padding(.vertical, 8)
        if let syncMessage { InlineIntegrationMessage(text: syncMessage, color: .secondary) }
        if let errorMessage { InlineIntegrationMessage(text: errorMessage, color: .red) }
    }
}

private struct InlineIntegrationMessage: View {
    let text: String
    let color: Color
    var body: some View { Text(text).font(.system(size: 12)).foregroundStyle(color).padding(.top, 4) }
}

private struct IntegrationRow: View {
    let icon: String
    let iconColor: Color
    let name: String
    let status: String
    let connected: Bool
    let isLoading: Bool
    let isSyncing: Bool
    let connect: () -> Void
    let sync: () -> Void
    let disconnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(iconColor).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) { Text(name).font(.system(size: 15, weight: .semibold)); Text(status).font(.system(size: 12)).foregroundStyle(connected ? Color.green : Color(.systemGray)) }
            Spacer()
            if isLoading { ProgressView().frame(width: 60) }
            else if connected {
                HStack(spacing: 8) {
                    Button(action: sync) { Text(isSyncing ? "Syncing…" : "Sync").font(.system(size: 13, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 6).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.systemGray3))) }.disabled(isSyncing)
                    Button("Disconnect", role: .destructive, action: disconnect).font(.system(size: 13, weight: .medium))
                }
            } else { Button("Connect", action: connect).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 14).padding(.vertical, 6).background(.black).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 6)) }
        }.padding(.vertical, 8)
    }
}

// MARK: - StravaRow

struct StravaRow: View {
    @ObservedObject var strava: StravaService
    @Binding var errorMessage: String?
    @Binding var syncMessage: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("Strava")
                    .font(.system(size: 15, weight: .semibold))
                Text(strava.status?.connected == true ? "Connected" : "Not connected")
                    .font(.system(size: 12))
                    .foregroundStyle(strava.status?.connected == true ? Color.green : Color(.systemGray))
            }

            Spacer()

            if strava.isLoading {
                ProgressView().frame(width: 60)
            } else if strava.status?.connected == true {
                HStack(spacing: 8) {
                    Button(action: syncStrava) {
                        if strava.isSyncing {
                            ProgressView().frame(width: 44)
                        } else {
                            Text("Sync")
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.systemGray3)))
                        }
                    }
                    .disabled(strava.isSyncing)

                    Button(action: disconnectStrava) {
                        Text("Disconnect")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                    }
                }
            } else {
                Button(action: connectStrava) {
                    Text("Connect")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func connectStrava() {
        errorMessage = nil
        Task {
            do {
                let url = try await strava.connectURL()
                openURL(url)
                // Refresh status when user returns — handled by onReceive scenePhase in RunnitApp
            } catch {
                errorMessage = "Could not start Strava connection."
            }
        }
    }

    private func syncStrava() {
        errorMessage = nil
        syncMessage = nil
        Task {
            do {
                let count = try await strava.sync()
                syncMessage = "\(count) activit\(count == 1 ? "y" : "ies") imported"
            } catch {
                errorMessage = "Sync failed. Try again."
            }
        }
    }

    private func disconnectStrava() {
        errorMessage = nil
        Task {
            do {
                try await strava.disconnect()
            } catch {
                errorMessage = "Could not disconnect Strava."
            }
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var displayName = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var sport = ""
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("PROFILE") {
                    RunnitTextField(label: "DISPLAY NAME", text: $displayName)
                    RunnitTextField(label: "BIO", text: $bio)
                    RunnitTextField(label: "LOCATION", text: $location)
                    RunnitTextField(label: "PRIMARY SPORT", text: $sport)
                }
                if let error { Text(error).foregroundStyle(.red).font(.system(size: 13)) }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(isSaving)
                }
            }
            .onAppear {
                if let user = auth.currentUser {
                    displayName = user.displayName
                    bio = user.bio ?? ""
                    location = user.location ?? ""
                    sport = user.sport ?? ""
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            do {
                try await auth.updateProfile(
                    displayName: displayName.isEmpty ? nil : displayName,
                    bio: bio.isEmpty ? nil : bio,
                    location: location.isEmpty ? nil : location,
                    sport: sport.isEmpty ? nil : sport
                )
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }
}
