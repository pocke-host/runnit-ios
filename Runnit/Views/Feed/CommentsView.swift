import SwiftUI

struct CommentsView: View {
    let activityId: Int
    @StateObject private var service = CommentService()
    @State private var newComment = ""
    @State private var isPosting = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if service.isLoading && service.comments.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if service.comments.isEmpty {
                    ContentUnavailableView(
                        "No comments yet",
                        systemImage: "bubble",
                        description: Text("Be the first to comment.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(service.comments) { comment in
                                CommentRow(comment: comment)
                            }
                        }
                        .padding(16)
                    }
                }
            }

            Divider()

            // Input bar
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Add a comment...", text: $newComment, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .padding(.vertical, 10)

                Button(action: postComment) {
                    if isPosting {
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(canPost ? .black : Color(.systemGray4))
                    }
                }
                .disabled(!canPost || isPosting)
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .task { try? await service.fetchComments(activityId: activityId) }
    }

    private var canPost: Bool {
        !newComment.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func postComment() {
        let text = newComment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isPosting = true
        newComment = ""
        inputFocused = false
        Task {
            _ = try? await service.postComment(activityId: activityId, content: text)
            isPosting = false
        }
    }
}

struct CommentRow: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: comment.userAvatarUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color(.systemGray5))
                    .overlay(
                        Text((comment.userDisplayName ?? "?").prefix(1).uppercased())
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.secondary)
                    )
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.userDisplayName ?? "Athlete")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    if let date = comment.createdAt {
                        Text(date.formatted(.relative(presentation: .named)))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(comment.content)
                    .font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
