import Foundation

// MARK: - Club model

struct Club: Identifiable, Decodable {
    let id: Int
    let name: String
    let sport: String?
    let description: String?
    let imageUrl: String?
    let memberCount: Int
    let isPrivate: Bool
    let city: String?
    let latitude: Double?
    let longitude: Double?
}

// MARK: - ClubService

@MainActor
final class ClubService: ObservableObject {
    static let shared = ClubService()

    private let api = APIClient.shared

    @Published var clubs: [Club] = []
    @Published var nearbyClubs: [Club] = []
    @Published var myClubs: [Club] = []
    @Published var isLoading = false

    private init() {}

    // MARK: - Search

    /// Searches clubs by name, city, and/or sport via `GET /api/clubs/search`
    func searchClubs(query: String, city: String?) async throws {
        var components = URLComponents()
        var items: [URLQueryItem] = []
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "q", value: trimmed))
        }
        if let city, !city.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "city", value: city.trimmingCharacters(in: .whitespaces)))
        }
        components.queryItems = items.isEmpty ? nil : items
        let query = components.url?.query.map { "?\($0)" } ?? ""

        isLoading = true
        defer { isLoading = false }
        clubs = try await api.request("/clubs/search\(query)")
    }

    // MARK: - Nearby

    /// Fetches clubs within 25km of the given coordinates via `GET /api/clubs/nearby`
    func fetchNearby(lat: Double, lng: Double) async throws {
        isLoading = true
        defer { isLoading = false }
        nearbyClubs = try await api.request("/clubs/nearby?lat=\(lat)&lng=\(lng)&radiusKm=25")
    }

    // MARK: - My Clubs

    /// Fetches the current user's clubs via `GET /api/clubs/my`
    func fetchMyClubs() async throws {
        isLoading = true
        defer { isLoading = false }
        myClubs = try await api.request("/clubs/my")
    }

    // MARK: - Join / Leave

    /// Joins a club via `POST /api/clubs/{id}/join`
    func joinClub(id: Int) async throws {
        try await api.requestVoid("/clubs/\(id)/join", method: "POST")
        // Refresh my-clubs list after joining
        myClubs = try await api.request("/clubs/my")
    }

    /// Leaves a club via `DELETE /api/clubs/{id}/leave`
    func leaveClub(id: Int) async throws {
        try await api.requestVoid("/clubs/\(id)/leave", method: "DELETE")
        // Remove the left club from local state immediately
        myClubs.removeAll { $0.id == id }
    }
}
