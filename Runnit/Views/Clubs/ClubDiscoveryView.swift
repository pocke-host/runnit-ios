import SwiftUI
import CoreLocation

// MARK: - ClubDiscoveryView

struct ClubDiscoveryView: View {
    @StateObject private var clubService = ClubService.shared
    @StateObject private var locationService = LocationService.shared

    @State private var selectedSegment = 0   // 0 = Nearby, 1 = Search
    @State private var searchQuery = ""
    @State private var cityQuery = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var selectedClub: Club?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment control
                Picker("Mode", selection: $selectedSegment) {
                    Text("Nearby").tag(0)
                    Text("Search").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                if selectedSegment == 0 {
                    NearbyClubsSection(
                        clubService: clubService,
                        locationService: locationService,
                        errorMessage: $errorMessage,
                        selectedClub: $selectedClub
                    )
                } else {
                    SearchClubsSection(
                        clubService: clubService,
                        searchQuery: $searchQuery,
                        cityQuery: $cityQuery,
                        searchTask: $searchTask,
                        errorMessage: $errorMessage,
                        selectedClub: $selectedClub
                    )
                }
            }
            .navigationTitle("Clubs")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedClub) { club in
                ClubDetailView(club: club)
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

// MARK: - Nearby Section

private struct NearbyClubsSection: View {
    @ObservedObject var clubService: ClubService
    @ObservedObject var locationService: LocationService
    @Binding var errorMessage: String?
    @Binding var selectedClub: Club?

    var body: some View {
        Group {
            switch locationService.authorizationStatus {
            case .notDetermined:
                VStack(spacing: 16) {
                    Image(systemName: "location.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Allow Location Access")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Runnit needs your location to show nearby run crews.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Allow Location") {
                        locationService.requestPermission()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .denied, .restricted:
                ContentUnavailableView(
                    "Location Denied",
                    systemImage: "location.slash",
                    description: Text("Enable location access in Settings to find nearby clubs.")
                )

            default:
                if clubService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if clubService.nearbyClubs.isEmpty {
                    ContentUnavailableView(
                        "No Nearby Clubs",
                        systemImage: "mappin.slash",
                        description: Text("No clubs found within 25km of your location.")
                    )
                } else {
                    List(clubService.nearbyClubs) { club in
                        ClubRow(club: club, isJoined: false)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .listRowSeparator(.hidden)
                            .onTapGesture { selectedClub = club }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .task {
            // Kick off location fetch whenever this section appears and we have permission
            await loadNearby()
        }
        .onChange(of: locationService.authorizationStatus) { _, status in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                Task { await loadNearby() }
            }
        }
    }

    private func loadNearby() async {
        guard locationService.authorizationStatus == .authorizedWhenInUse
                || locationService.authorizationStatus == .authorizedAlways else { return }
        guard let loc = locationService.currentLocation else {
            // Trigger a location update so we get coordinates
            locationService.requestPermission()
            return
        }
        do {
            try await clubService.fetchNearby(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Search Section

private struct SearchClubsSection: View {
    @ObservedObject var clubService: ClubService
    @Binding var searchQuery: String
    @Binding var cityQuery: String
    @Binding var searchTask: Task<Void, Never>?
    @Binding var errorMessage: String?
    @Binding var selectedClub: Club?

    var body: some View {
        VStack(spacing: 0) {
            // Search inputs
            VStack(spacing: 8) {
                SearchBar(placeholder: "Club name or sport...", text: $searchQuery)
                    .onChange(of: searchQuery) { _, _ in debounce() }
                SearchBar(placeholder: "City (optional)", text: $cityQuery)
                    .onChange(of: cityQuery) { _, _ in debounce() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            Group {
                if clubService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchQuery.isEmpty && cityQuery.isEmpty {
                    ContentUnavailableView(
                        "Find Your Crew",
                        systemImage: "person.3",
                        description: Text("Search by club name, sport, or city.")
                    )
                } else if clubService.clubs.isEmpty {
                    ContentUnavailableView(
                        "No Clubs Found",
                        systemImage: "person.3.slash",
                        description: Text("Try a different search term or city.")
                    )
                } else {
                    List(clubService.clubs) { club in
                        ClubRow(club: club, isJoined: false)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .listRowSeparator(.hidden)
                            .onTapGesture { selectedClub = club }
                    }
                    .listStyle(.plain)
                }
            }
        }
    }

    private func debounce() {
        searchTask?.cancel()
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
                || !cityQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            clubService.clubs = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            do {
                try await clubService.searchClubs(
                    query: searchQuery,
                    city: cityQuery.isEmpty ? nil : cityQuery
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - ClubRow

struct ClubRow: View {
    let club: Club
    let isJoined: Bool

    @State private var joined: Bool
    @State private var isLoading = false

    init(club: Club, isJoined: Bool) {
        self.club = club
        self.isJoined = isJoined
        _joined = State(initialValue: isJoined)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Club avatar / icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 52, height: 52)
                Text(club.name.prefix(1).uppercased())
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(club.name)
                    .font(.system(size: 15, weight: .semibold))

                HStack(spacing: 8) {
                    if let sport = club.sport {
                        sportTag(sport)
                    }
                    if let city = club.city {
                        Label(city, systemImage: "mappin")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Label("\(club.memberCount) members", systemImage: "person.2")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: toggleJoin) {
                Group {
                    if isLoading {
                        ProgressView()
                            .frame(width: 72, height: 32)
                    } else {
                        Text(joined ? "Joined" : "Join")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 72, height: 32)
                            .background(joined ? Color(.systemGray5) : .black)
                            .foregroundStyle(joined ? .primary : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }

    private func sportTag(_ sport: String) -> some View {
        Text(sport)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.black)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func toggleJoin() {
        let wasJoined = joined
        joined.toggle() // optimistic
        isLoading = true
        Task {
            do {
                if wasJoined {
                    try await ClubService.shared.leaveClub(id: club.id)
                } else {
                    try await ClubService.shared.joinClub(id: club.id)
                }
            } catch {
                joined = wasJoined // revert on failure
            }
            isLoading = false
        }
    }
}

// MARK: - ClubDetailView

struct ClubDetailView: View {
    let club: Club
    @StateObject private var clubService = ClubService.shared
    @State private var isJoined = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header banner
                ZStack {
                    Rectangle()
                        .fill(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                    VStack(spacing: 8) {
                        Text(club.name.prefix(2).uppercased())
                            .font(.system(size: 48, weight: .black))
                            .foregroundStyle(.white)
                        if let sport = club.sport {
                            Text(sport)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(.systemGray3))
                        }
                    }
                }

                // Meta info
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 24) {
                        statBlock(label: "MEMBERS", value: "\(club.memberCount)")
                        if let city = club.city {
                            statBlock(label: "CITY", value: city)
                        }
                        statBlock(label: "TYPE", value: club.isPrivate ? "Private" : "Public")
                    }
                    .padding(.top, 20)

                    if let description = club.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ABOUT")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(.secondary)
                            Text(description)
                                .font(.system(size: 15))
                        }
                    }

                    // Join / Leave button
                    Button(action: toggleJoin) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        } else {
                            Text(isJoined ? "Leave Club" : "Join Club")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(isJoined ? Color(.systemGray5) : .black)
                                .foregroundStyle(isJoined ? .primary : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(club.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            // Check if this club is in the user's joined clubs
            isJoined = clubService.myClubs.contains { $0.id == club.id }
        }
    }

    private func statBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .black))
        }
    }

    private func toggleJoin() {
        let wasJoined = isJoined
        isJoined.toggle() // optimistic
        isLoading = true
        Task {
            do {
                if wasJoined {
                    try await ClubService.shared.leaveClub(id: club.id)
                } else {
                    try await ClubService.shared.joinClub(id: club.id)
                }
            } catch {
                isJoined = wasJoined // revert on failure
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Reusable search bar

private struct SearchBar: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
