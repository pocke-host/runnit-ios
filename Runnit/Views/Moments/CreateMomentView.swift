import SwiftUI
import UIKit

struct CreateMomentView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImage: UIImage?
    @State private var caption = ""
    @State private var songTitle = ""
    @State private var songArtist = ""
    @State private var songLink = ""
    @State private var selectedActivityId: Int?
    @State private var recentActivities: [Activity] = []
    @State private var isPosting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    CameraPickerView(selectedImage: $selectedImage)

                    VStack(alignment: .leading, spacing: 20) {

                        // Caption
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CAPTION")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(.secondary)
                            TextField("What's on your mind?", text: $caption, axis: .vertical)
                                .lineLimit(1...4)
                                .font(.system(size: 15))
                        }

                        Divider()

                        // Song
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SONG")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                                VStack(spacing: 6) {
                                    TextField("Song title", text: $songTitle)
                                        .font(.system(size: 14))
                                    TextField("Artist", text: $songArtist)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            // TODO: replace with SpotifyPickerView once Spotify integration is complete
                        }

                        Divider()

                        // Link to activity
                        if !recentActivities.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("LINK AN ACTIVITY")
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(recentActivities) { activity in
                                            let selected = selectedActivityId == activity.id
                                            Button {
                                                selectedActivityId = selected ? nil : activity.id
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: activity.activityIcon)
                                                    Text(activity.title ?? activity.activityType.capitalized)
                                                        .lineLimit(1)
                                                }
                                                .font(.system(size: 12, weight: .semibold))
                                                .padding(.horizontal, 12).padding(.vertical, 8)
                                                .background(selected ? Color.black : Color(.systemGray6))
                                                .foregroundStyle(selected ? .white : .primary)
                                                .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            Divider()
                        }

                        // Post button
                        Button(action: post) {
                            Group {
                                if isPosting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Post Moment").font(.system(size: 15, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(selectedImage != nil ? Color.black : Color(.systemGray4))
                            .foregroundStyle(.white)
                        }
                        .disabled(selectedImage == nil || isPosting)
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadRecentActivities() }
            .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Actions

    private func loadRecentActivities() async {
        struct Page: Decodable { let content: [Activity] }
        if let page: Page = try? await APIClient.shared.request("/activities?page=0&size=10") {
            recentActivities = page.content
        }
    }

    private func post() {
        guard let image = selectedImage else { return }
        isPosting = true
        Task {
            do {
                let photoUrl = try await MediaUploadService.shared.upload(image: image, folder: "moments")
                struct Body: Encodable {
                    let photoUrl, caption: String
                    let songTitle, songArtist, songLink: String?
                    let activityId: Int?
                }
                try await APIClient.shared.requestVoid(
                    "/moments", method: "POST",
                    body: Body(
                        photoUrl: photoUrl,
                        caption: caption,
                        songTitle: songTitle.isEmpty ? nil : songTitle,
                        songArtist: songArtist.isEmpty ? nil : songArtist,
                        songLink: songLink.isEmpty ? nil : songLink,
                        activityId: selectedActivityId
                    )
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isPosting = false
        }
    }
}
