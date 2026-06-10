import Foundation

struct UserSummary: Codable, Identifiable {
    let id: Int
    let user: String            // username/handle
    let displayName: String
    let avatarUrl: String?
    let bio: String?
    let sport: String?
    let followerCount: Int?
    let followingCount: Int?
    var isFollowing: Bool?

    var avatarURL: URL? { avatarUrl.flatMap(URL.init) }
}

@MainActor
final class UserService: ObservableObject {
    static let shared = UserService()

    private let api = APIClient.shared

    @Published var searchResults: [UserSummary] = []
    @Published var isSearching = false

    private init() {}

    func searchUsers(query: String) async throws {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        searchResults = try await api.request("/users/search?query=\(encoded)")
    }

    func followUser(userId: Int) async throws {
        try await api.requestVoid("/follow/\(userId)", method: "POST")
    }

    func unfollowUser(userId: Int) async throws {
        try await api.requestVoid("/follow/\(userId)", method: "DELETE")
    }
}
