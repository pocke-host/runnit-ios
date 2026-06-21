import SwiftUI

struct DiscoverView: View {
    @StateObject private var service = UserService.shared
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search athletes...", text: $query)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: query) { _, new in debounceSearch(new) }
                    if !query.isEmpty {
                        Button {
                            query = ""
                            service.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                Group {
                    if service.isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if query.isEmpty {
                        ContentUnavailableView(
                            "Find Athletes",
                            systemImage: "person.2",
                            description: Text("Search by name or @username to find athletes to follow.")
                        )
                    } else if service.searchResults.isEmpty {
                        ContentUnavailableView(
                            "No athletes found",
                            systemImage: "person.slash",
                            description: Text("Try a different name or username.")
                        )
                    } else {
                        List(service.searchResults) { user in
                            UserRow(user: user)
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func debounceSearch(_ q: String) {
        searchTask?.cancel()
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else {
            service.searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            do {
                try await service.searchUsers(query: q)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct UserRow: View {
    let user: UserSummary
    @State private var isFollowing: Bool
    @State private var isLoading = false

    init(user: UserSummary) {
        self.user = user
        _isFollowing = State(initialValue: user.isFollowing ?? false)
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: user.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color(.systemGray5))
                    .overlay(
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.secondary)
                    )
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 15, weight: .semibold))
                Text("@\(user.user)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                if let sport = user.sport {
                    Label(sport, systemImage: "figure.run")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: toggleFollow) {
                Group {
                    if isLoading {
                        ProgressView()
                            .frame(width: 80, height: 32)
                    } else {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 80, height: 32)
                            .background(isFollowing ? Color(.systemGray5) : .black)
                            .foregroundStyle(isFollowing ? .primary : .white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }

    private func toggleFollow() {
        isLoading = true
        let wasFollowing = isFollowing
        isFollowing.toggle() // optimistic
        Task {
            do {
                if wasFollowing {
                    try await UserService.shared.unfollowUser(userId: user.id)
                } else {
                    try await UserService.shared.followUser(userId: user.id)
                }
            } catch {
                isFollowing = wasFollowing // revert on failure
            }
            isLoading = false
        }
    }
}
