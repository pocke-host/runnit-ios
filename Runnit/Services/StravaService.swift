import Foundation

struct StravaStatus: Decodable {
    let connected: Bool
    let lastSync: String?
}

@MainActor
final class StravaService: ObservableObject {
    static let shared = StravaService()
    private let api = APIClient.shared

    @Published var status: StravaStatus?
    @Published var isLoading = false
    @Published var isSyncing = false

    private init() {}

    func fetchStatus() async throws {
        isLoading = true
        defer { isLoading = false }
        status = try await api.request("/integrations/strava/status")
    }

    func connectURL() async throws -> URL {
        struct Response: Decodable { let url: String }
        let res: Response = try await api.request("/integrations/strava/connect")
        guard let url = URL(string: res.url) else { throw URLError(.badURL) }
        return url
    }

    func sync() async throws -> Int {
        isSyncing = true
        defer { isSyncing = false }
        struct Response: Decodable { let imported: Int }
        let res: Response = try await api.request("/integrations/strava/sync", method: "POST")
        return res.imported
    }

    func disconnect() async throws {
        try await api.requestVoid("/integrations/strava/disconnect", method: "DELETE")
        status = StravaStatus(connected: false, lastSync: nil)
    }
}
