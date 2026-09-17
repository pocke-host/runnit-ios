import Foundation

struct Comment: Codable, Identifiable {
    let id: Int
    let text: String
    let createdAt: Date?
    let user: CommentUser?
    let parentId: Int?
    let mediaUrl: String?
    let mediaType: String?

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

struct GifResult: Codable, Identifiable {
    let id: String
    let title: String?
    let url: String
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

    func searchGifs(query: String) async throws -> [GifResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await api.request("/giphy/search?q=\(encoded)", authenticated: true)
    }

    func postComment(activityId: Int, content: String, parentId: Int? = nil, mediaUrl: String? = nil, mediaType: String? = nil) async throws -> Comment {
        struct Body: Encodable {
            let text: String
            let parentId: Int?
            let mediaUrl: String?
            let mediaType: String?
        }
        let comment: Comment = try await api.request(
            "/activities/\(activityId)/comments",
            method: "POST",
            body: Body(text: content, parentId: parentId, mediaUrl: mediaUrl, mediaType: mediaType)
        )
        comments.append(comment)
        return comment
    }
}
