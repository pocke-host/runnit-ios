import SwiftUI

struct FeedView: View {
    @StateObject private var service = ActivityService.shared
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if service.isLoading && service.feed.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if service.feed.isEmpty {
                    ContentUnavailableView("No activity yet", systemImage: "figure.run", description: Text("Follow athletes or log your first run."))
                } else {
                    List {
                        ForEach(service.feed) { activity in
                            NavigationLink(destination: ActivityDetailView(activityId: activity.id)) {
                                ActivityCard(activity: activity)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { try? await service.fetchFeed() }
                }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.large)
            .task { try? await service.fetchFeed() }
        }
    }
}
