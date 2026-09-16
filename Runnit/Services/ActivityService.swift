import Foundation

struct WeeklyExerciseSummary: Decodable {
    let weekStart: String
    let weekEnd: String
    let totalDurationSeconds: Int
    let previousTotalDurationSeconds: Int?
    let changePercent: Int?
    let plannedDurationMinutes: Int?
    let completedPlannedDurationMinutes: Int?
    let plannedCount: Int?
    let activityCount: Int
    let daily: [DailyExerciseSummary]
    let bySport: [ExerciseBreakdown]
    let bySource: [SourceExerciseBreakdown]

    var formattedTotal: String {
        let hours = totalDurationSeconds / 3600
        let minutes = (totalDurationSeconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

struct DailyExerciseSummary: Decodable, Identifiable {
    let date: String
    let durationSeconds: Int
    let activityCount: Int
    var id: String { date }
}

struct ExerciseBreakdown: Decodable, Identifiable {
    let sport: String
    let durationSeconds: Int
    var id: String { sport }
}

struct SourceExerciseBreakdown: Decodable, Identifiable {
    let source: String
    let durationSeconds: Int
    var id: String { source }
}

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

    func fetchWeeklySummary(weekStart: String? = nil) async throws -> WeeklyExerciseSummary {
        let timezone = TimeZone.current.identifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "UTC"
        var path = "/activities/summary/weekly?timezone=\(timezone)"
        if let weekStart { path += "&weekStart=\(weekStart)" }
        return try await api.request(path)
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
