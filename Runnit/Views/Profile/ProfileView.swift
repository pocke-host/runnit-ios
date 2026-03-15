import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @StateObject private var activityService = ActivityService.shared
    @State private var showEditProfile = false
    @State private var showLogoutConfirm = false

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
                                Circle().fill(Color(.systemGray5))
                                    .overlay(Text(user.displayName.prefix(1).uppercased())
                                        .font(.system(size: 32, weight: .black)).foregroundStyle(.secondary))
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())

                            VStack(spacing: 4) {
                                Text(user.displayName)
                                    .font(.system(size: 22, weight: .black))
                                Text("@\(user.user)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }

                            if let bio = user.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.system(size: 14))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 32)
                            }

                            HStack(spacing: 8) {
                                if let sport = user.sport {
                                    Label(sport, systemImage: "figure.run")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                if let location = user.location {
                                    Label(location, systemImage: "mappin")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(.black)
                        .foregroundStyle(.white)

                        // Edit profile button
                        Button("Edit Profile") { showEditProfile = true }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .overlay(Rectangle().stroke(.black, lineWidth: 1))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
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
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .confirmationDialog("Log out of Runnit?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Log Out", role: .destructive) { auth.logout() }
                Button("Cancel", role: .cancel) {}
            }
            .task { try? await activityService.fetchMyActivities() }
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
