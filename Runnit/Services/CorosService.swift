import Foundation

struct CorosStatus: Decodable {
    let connected: Bool
    let lastSync: String?
}

@MainActor
final class CorosService: ObservableObject {
    static let shared = CorosService()
    private let api = APIClient.shared

    @Published var status: CorosStatus?
    @Published var isLoading = false
    @Published var isSyncing = false

    private init() {}

    func fetchStatus() async {
        isLoading = true
        defer { isLoading = false }
        do {
            status = try await api.request("/integrations/coros/status")
        } catch {
            print("[COROS] fetchStatus failed: \(error.localizedDescription)")
        }
    }

    func connectURL() async throws -> URL {
        struct Response: Decodable { let url: String }
        let res: Response = try await api.request("/integrations/coros/connect")
        guard let url = URL(string: res.url) else { throw URLError(.badURL) }
        OAuthStateStore.shared.register(provider: "coros", url: url)
        return url
    }

    func sync() async throws -> Int {
        isSyncing = true
        defer { isSyncing = false }
        struct Response: Decodable { let imported: Int }
        let res: Response = try await api.request("/integrations/coros/sync", method: "POST")
        return res.imported
    }

    func disconnect() async throws {
        try await api.requestVoid("/integrations/coros/disconnect", method: "DELETE")
        status = CorosStatus(connected: false, lastSync: nil)
    }
}
