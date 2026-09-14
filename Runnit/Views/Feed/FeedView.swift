import SwiftUI

struct FeedView: View {
    let onRecord: () -> Void
    @StateObject private var service = ActivityService.shared
    @State private var errorMessage: String?
    @State private var quoteIndex = 0

    init(onRecord: @escaping () -> Void = {}) {
        self.onRecord = onRecord
    }

    private let quotes = [
        "Small steps. Stronger days.",
        "Your pace. Your people. Your story.",
        "Consistency is a quiet kind of confidence.",
        "Go easy. Go far. Keep going.",
        "The best workout is the one that fits your life."
    ]

    var body: some View {
        NavigationStack {
            Group {
                if service.isLoading && service.feed.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if service.feed.isEmpty {
                    VStack(spacing: 20) {
                        quoteCard
                        VStack(spacing: 10) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(RunnitTheme.signal)
                            Text("Your feed starts here")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(RunnitTheme.ink)
                            Text("Record a workout or find athletes to follow. Your next chapter belongs here.")
                                .font(.system(size: 15))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(RunnitTheme.muted)
                                .padding(.horizontal, 28)
                            Button("Record an activity", action: onRecord)
                                .buttonStyle(RunnitPrimaryButtonStyle())
                                .padding(.horizontal, 28)
                        }
                        .padding(.top, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
                } else {
                    List {
                        Section { quoteCard }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                            .listRowSeparator(.hidden)
                        ForEach(service.feed) { activity in
                            NavigationLink(destination: ActivityDetailView(activityId: activity.id)) {
                                ActivityCard(activity: activity)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .onAppear {
                                if activity.id == service.feed.last?.id {
                                    Task { try? await service.fetchMoreFeed() }
                                }
                            }
                        }
                        if service.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(RunnitTheme.canvas)
                    .refreshable {
                        do { try await service.fetchFeed() }
                        catch { errorMessage = error.localizedDescription }
                    }
                }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.large)
            .background(RunnitTheme.canvas)
            .task {
                do { try await service.fetchFeed() }
                catch { errorMessage = error.localizedDescription }
            }
            .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var quoteCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "quote.opening")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(RunnitTheme.ink)
                .frame(width: 38, height: 38)
                .background(RunnitTheme.yellow)
                .clipShape(RoundedRectangle(cornerRadius: RunnitTheme.radius))

            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY'S ENERGY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(RunnitTheme.signal)
                Text(quotes[quoteIndex])
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(RunnitTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Shuffle") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        quoteIndex = (quoteIndex + 1) % quotes.count
                    }
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(RunnitTheme.signal)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white)
        .overlay(Rectangle().stroke(RunnitTheme.rule))
    }
}
