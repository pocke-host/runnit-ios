import Foundation

struct StravaStatus: Decodable { let connected: Bool; let lastSync: String? }

@MainActor
final class StravaService: ObservableObject {
    static let shared = StravaService()
    private let api = APIClient.shared
    @Published var status: StravaStatus?
    @Published var isLoading = false
    @Published var isSyncing = false
    private init() {}
    func fetchStatus() async throws { isLoading = true; defer { isLoading = false }; status = try await api.request("/integrations/strava/status") }
    func connectURL() async throws -> URL { struct Response: Decodable { let url: String }; let response: Response = try await api.request("/integrations/strava/connect"); guard let url = URL(string: response.url) else { throw APIError.invalidURL }; return url }
    func sync() async throws -> Int { isSyncing = true; defer { isSyncing = false }; struct Response: Decodable { let imported: Int }; let response: Response = try await api.request("/integrations/strava/sync", method: "POST"); return response.imported }
    func disconnect() async throws { try await api.requestVoid("/integrations/strava/disconnect", method: "DELETE"); status = StravaStatus(connected: false, lastSync: nil) }
}
