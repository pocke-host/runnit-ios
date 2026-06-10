import Foundation

struct Comment: Codable, Identifiable {
    let id: Int
    let text: String
    let createdAt: Date?
    let user: CommentUser?

    struct CommentUser: Codable {
        let id: Int
        let displayName: String?
        let avatarUrl: String?
    }

    // Convenience aliases so CommentsView doesn't need touching
    var content: String { text }
    var userDisplayName: String? { user?.displayName }
    var userAvatarUrl: String? { user?.avatarUrl }
}

@MainActor
final class CommentService: ObservableObject {
    private let api = APIClient.shared

    @Published var comments: [Comment] = []
    @Published var isLoading = false

    func fetchComments(activityId: Int) async throws {
        isLoading = true
        defer { isLoading = false }
        comments = try await api.request("/activities/\(activityId)/comments")
    }

    func postComment(activityId: Int, content: String) async throws -> Comment {
        struct Body: Encodable { let text: String }
        let comment: Comment = try await api.request(
            "/activities/\(activityId)/comments",
            method: "POST",
            body: Body(text: content)
        )
        comments.append(comment)
        return comment
    }
}
