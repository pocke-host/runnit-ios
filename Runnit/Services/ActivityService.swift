import Foundation

@MainActor
final class ActivityService: ObservableObject {
    static let shared = ActivityService()
    private let api = APIClient.shared

    @Published var feed: [Activity] = []
    @Published var myActivities: [Activity] = []
    @Published var isLoading = false
    @Published var hasMoreFeed = true

    private var feedPage = 0

    private struct PageResponse: Decodable { let content: [Activity]; let last: Bool }

    private init() {}

    // MARK: - Feed (followed users + own)

    func fetchFeed() async throws {
        guard !isLoading else { return }
        isLoading = true
        feedPage = 0
        defer { isLoading = false }
        let result: PageResponse = try await api.request("/activities/feed?page=0&size=20")
        feed = result.content
        hasMoreFeed = !result.last
        feedPage = 1
    }

    func fetchMoreFeed() async throws {
        guard !isLoading, hasMoreFeed else { return }
        isLoading = true
        defer { isLoading = false }
        let result: PageResponse = try await api.request("/activities/feed?page=\(feedPage)&size=20")
        feed.append(contentsOf: result.content)
        hasMoreFeed = !result.last
        feedPage += 1
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
