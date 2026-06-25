import Foundation

// MARK: - SpotifyTrack model

struct SpotifyTrack: Identifiable, Decodable {
    let id: String
    let name: String
    let artist: String
    let albumName: String?
    let previewUrl: String?
    let externalUrl: String?
}

// MARK: - SpotifySearchService

@MainActor
final class SpotifySearchService: ObservableObject {
    static let shared = SpotifySearchService()

    private let api = APIClient.shared

    @Published var results: [SpotifyTrack] = []
    @Published var isSearching = false

    private init() {}

    /// Searches Spotify for tracks matching the given query.
    /// `GET /api/spotify/search?q=QUERY`
    func search(query: String) async throws {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            results = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        results = try await api.request("/spotify/search?q=\(encoded)")
    }
}
