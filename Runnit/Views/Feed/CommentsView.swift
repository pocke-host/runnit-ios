import SwiftUI

struct CommentsView: View {
    let activityId: Int
    @StateObject private var service = CommentService()
    @StateObject private var userService = UserService.shared
    @State private var newComment = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var replyTo: Comment?
    @State private var mentionSuggestions: [UserSummary] = []
    @State private var mentionTask: Task<Void, Never>?
    @State private var showGifPicker = false
    @State private var selectedGif: GifResult?
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
                                CommentRow(comment: comment, onReply: { replyTo = comment })
                            }
                        }
                        .padding(16)
                    }
                }
            }

            Divider()

            // Input bar
            if !mentionSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(mentionSuggestions) { user in
                            Button { insertMention(user) } label: {
                                HStack(spacing: 6) {
                                    Circle().fill(RunnitTheme.yellow).frame(width: 24, height: 24)
                                        .overlay(Text(user.displayName.prefix(1)).font(.caption2.bold()))
                                    Text("@\(user.user)").font(.system(size: 12, weight: .bold, design: .monospaced))
                                }
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(Color.white)
                                .overlay(Rectangle().stroke(RunnitTheme.rule))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
                .background(RunnitTheme.canvas)
            }
            if let selectedGif {
                HStack(spacing: 8) {
                    AsyncImage(url: URL(string: selectedGif.url)) { image in image.resizable().scaledToFill() } placeholder: { ProgressView() }
                        .frame(width: 70, height: 48).clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("GIF attached").font(.caption).foregroundStyle(RunnitTheme.muted)
                    Spacer()
                    Button { self.selectedGif = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(RunnitTheme.muted) }
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }
            HStack(alignment: .bottom, spacing: 12) {
                Button { showGifPicker = true } label: {
                    Text("GIF").font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(RunnitTheme.signal)
                }
                .accessibilityLabel("Add a GIF")
                TextField(replyTo == nil ? "Add a comment..." : "Reply to \(replyTo?.userDisplayName ?? "athlete")…", text: $newComment, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .onChange(of: newComment) { _, value in updateMentionSuggestions(value) }
                    .padding(.vertical, 10)

                Button(action: postComment) {
                    if isPosting {
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(canPost ? RunnitTheme.signal : RunnitTheme.rule)
                    }
                }
                .disabled(!canPost || isPosting)
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            if replyTo != nil { Text("Replying to a comment").font(.caption).foregroundStyle(RunnitTheme.muted).padding(.bottom, 4) }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .background(RunnitTheme.canvas)
        .sheet(isPresented: $showGifPicker) {
            GifPickerView { gif in
                selectedGif = gif
                showGifPicker = false
            }
        }
        .task {
            do { try await service.fetchComments(activityId: activityId) }
            catch { errorMessage = error.localizedDescription }
        }
        .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var canPost: Bool {
        !newComment.trimmingCharacters(in: .whitespaces).isEmpty || selectedGif != nil
    }

    private func postComment() {
        let text = newComment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty || selectedGif != nil else { return }
        isPosting = true
        newComment = ""
        inputFocused = false
        Task {
            do {
                _ = try await service.postComment(activityId: activityId, content: text, parentId: replyTo?.id, mediaUrl: selectedGif?.url, mediaType: selectedGif == nil ? nil : "GIF")
                replyTo = nil
                selectedGif = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isPosting = false
        }
    }

    private func updateMentionSuggestions(_ value: String) {
        mentionTask?.cancel()
        guard let token = value.split(whereSeparator: { $0 == " " || $0 == "\n" }).last,
              token.first == "@", token.count > 1 else {
            mentionSuggestions = []
            return
        }
        let query = String(token.dropFirst())
        mentionTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            try? await userService.searchUsers(query: query)
            guard !Task.isCancelled else { return }
            mentionSuggestions = Array(userService.searchResults.prefix(5))
        }
    }

    private func insertMention(_ user: UserSummary) {
        let parts = newComment.split(separator: " ", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return }
        var updated = parts.map(String.init)
        updated[updated.count - 1] = "@\(user.user)"
        newComment = updated.joined(separator: " ") + " "
        mentionSuggestions = []
        inputFocused = true
    }
}

struct CommentRow: View {
    let comment: Comment
    let onReply: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: comment.userAvatarUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(RunnitTheme.yellow)
                    .overlay(
                        Text((comment.userDisplayName ?? "?").prefix(1).uppercased())
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(RunnitTheme.ink)
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
                            .foregroundStyle(RunnitTheme.muted)
                    }
                }
                Text(comment.content)
                    .font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
                if let mediaUrl = comment.mediaUrl, comment.mediaType?.uppercased() == "GIF" {
                    AsyncImage(url: URL(string: mediaUrl)) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }
                        .frame(maxWidth: 220, maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Button("Reply", action: onReply)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(RunnitTheme.signal)
            }
        }.padding(.leading, comment.parentId == nil ? 0 : 24)
    }
}

private struct GifPickerView: View {
    let onSelect: (GifResult) -> Void
    @State private var query = "running"
    @State private var gifs: [GifResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(RunnitTheme.muted)
                    TextField("Search GIFs", text: $query)
                        .onSubmit { search() }
                    Button("Search") { search() }.font(.caption.bold()).foregroundStyle(RunnitTheme.signal)
                }
                .padding(12).background(Color.white).overlay(Rectangle().stroke(RunnitTheme.rule)).padding(.horizontal, 16)
                Group {
                    if isLoading {
                        ProgressView().frame(maxHeight: .infinity)
                    } else if gifs.isEmpty {
                        ContentUnavailableView("Find a reaction", systemImage: "face.smiling", description: Text("Search for a GIF to add to your comment."))
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(gifs) { gif in
                                    Button { onSelect(gif) } label: {
                                        AsyncImage(url: URL(string: gif.url)) { image in image.resizable().scaledToFill() } placeholder: { ProgressView() }
                                            .frame(height: 105)
                                            .frame(maxWidth: .infinity)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .background(RunnitTheme.canvas)
            .navigationTitle("GIFs").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task { search() }
            .alert("GIF search unavailable", isPresented: .init(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
    }

    private func search() {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        isLoading = true
        Task {
            do { gifs = try await CommentService().searchGifs(query: term) }
            catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }
}
