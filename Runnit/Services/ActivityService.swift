import Foundation

@MainActor
final class ActivityService: ObservableObject {
    static let shared = ActivityService()
    private let api = APIClient.shared

    @Published var feed: [Activity] = []
    @Published var myActivities: [Activity] = []
    @Published var isLoading = false

    private init() {}

    // MARK: - Feed (followed users + own)

    func fetchFeed(page: Int = 0) async throws {
        isLoading = true
        defer { isLoading = false }
        struct Page: Decodable { let content: [Activity] }
        let page: Page = try await api.request("/activities/feed?page=\(page)&size=20")
        if page.content.isEmpty { return }
        feed = page.content
    }

    // MARK: - My activities

    func fetchMyActivities(page: Int = 0) async throws {
        struct Page: Decodable { let content: [Activity] }
        let page: Page = try await api.request("/activities?page=\(page)&size=20")
        myActivities = page.content
    }

    // MARK: - Single activity

    func fetchActivity(id: Int) async throws -> Activity {
        try await api.request("/activities/\(id)")
    }

    // MARK: - Create activity (called after GPS session ends)

    func createActivity(_ body: CreateActivityBody) async throws -> Activity {
        try await api.request("/activities", method: "POST", body: body)
    }

    // MARK: - Delete

    func deleteActivity(id: Int) async throws {
        try await api.requestVoid("/activities/\(id)", method: "DELETE")
        feed.removeAll { $0.id == id }
        myActivities.removeAll { $0.id == id }
    }

    // MARK: - Reactions

    func addReaction(activityId: Int, type: String) async throws {
        struct Body: Encodable { let type: String }
        try await api.requestVoid("/activities/\(activityId)/reactions", method: "POST", body: Body(type: type))
    }

    func removeReaction(activityId: Int) async throws {
        try await api.requestVoid("/activities/\(activityId)/reactions", method: "DELETE")
    }
}
