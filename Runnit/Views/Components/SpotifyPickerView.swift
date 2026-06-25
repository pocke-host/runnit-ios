import SwiftUI

// MARK: - SpotifyPickerView

struct SpotifyPickerView: View {
    @Binding var selectedTrack: SpotifyTrack?
    @Environment(\.dismiss) private var dismiss

    @StateObject private var service = SpotifySearchService.shared
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search songs or artists...", text: $query)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: query) { _, new in debounce(new) }
                    if !query.isEmpty {
                        Button {
                            query = ""
                            service.results = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                Group {
                    if service.isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if query.isEmpty {
                        ContentUnavailableView(
                            "Search for a Track",
                            systemImage: "music.note",
                            description: Text("Find the song that fuels your runs.")
                        )
                    } else if service.results.isEmpty {
                        ContentUnavailableView(
                            "No Tracks Found",
                            systemImage: "music.note.slash",
                            description: Text("Try a different song or artist name.")
                        )
                    } else {
                        List(service.results) { track in
                            TrackRow(track: track)
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                                .listRowSeparator(.hidden)
                                .onTapGesture {
                                    selectedTrack = track
                                    dismiss()
                                }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Pick a Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Debounced search

    private func debounce(_ q: String) {
        searchTask?.cancel()
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else {
            service.results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            do {
                try await service.search(query: q)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - TrackRow

private struct TrackRow: View {
    let track: SpotifyTrack

    var body: some View {
        HStack(spacing: 12) {
            // Music note placeholder icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 48, height: 48)
                Image(systemName: "music.note")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let album = track.albumName {
                    Text(album)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.systemGray3))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundStyle(Color(.systemGray3))
        }
    }
}
