import SwiftUI
import UIKit

struct CreateStoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImage: UIImage?
    @State private var caption = ""
    @State private var visibility = "PUBLIC"
    @State private var isPosting = false
    @State private var errorMessage: String?

    private let visibilityOptions = [("PUBLIC", "Everyone"), ("FOLLOWERS", "Followers"), ("CLOSE_FRIENDS", "Close Friends")]

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
                            TextField("What's the vibe?", text: $caption, axis: .vertical)
                                .lineLimit(1...4)
                                .font(.system(size: 15))
                        }

                        Divider()

                        // Visibility
                        VStack(alignment: .leading, spacing: 10) {
                            Text("WHO CAN SEE THIS")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(visibilityOptions, id: \.0) { key, label in
                                    Button { visibility = key } label: {
                                        Text(label)
                                            .font(.system(size: 12, weight: .semibold))
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(visibility == key ? Color.black : Color(.systemGray6))
                                            .foregroundStyle(visibility == key ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Divider()

                        Button(action: post) {
                            Group {
                                if isPosting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Post Story").font(.system(size: 15, weight: .bold))
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
            .navigationTitle("New Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func post() {
        guard let image = selectedImage else { return }
        isPosting = true
        Task {
            do {
                let publicUrl = try await MediaUploadService.shared.upload(image: image, folder: "stories")
                struct Body: Encodable {
                    let mediaUrl, mediaType, caption, visibility: String
                }
                try await APIClient.shared.requestVoid(
                    "/stories", method: "POST",
                    body: Body(mediaUrl: publicUrl, mediaType: "IMAGE", caption: caption, visibility: visibility)
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isPosting = false
        }
    }
}
