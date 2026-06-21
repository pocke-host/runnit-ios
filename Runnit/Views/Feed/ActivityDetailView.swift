import SwiftUI
import MapKit

struct ActivityDetailView: View {
    let activityId: Int
    @State private var activity: Activity?
    @State private var isLoading = true
    @State private var localReactionCount: Int = 0
    @State private var localUserReaction: String?
    @State private var isReacting = false
    @State private var showComments = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let a = activity {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Route map
                        if let points = a.routePoints, !points.isEmpty {
                            RouteMapView(points: points)
                                .frame(height: 260)
                        }

                        VStack(alignment: .leading, spacing: 20) {
                            // Title + meta
                            VStack(alignment: .leading, spacing: 4) {
                                Label(a.activityType.capitalized, systemImage: a.activityIcon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Text(a.title ?? a.activityType.capitalized)
                                    .font(.system(size: 24, weight: .black))
                                if let date = a.date {
                                    Text(date.formatted(date: .long, time: .shortened))
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Divider()

                            // Stats grid
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 20
                            ) {
                                if let d = a.distanceMeters {
                                    BigStat(label: "Distance", value: String(format: "%.2f", d / 1000), unit: "km")
                                }
                                if a.durationSeconds != nil {
                                    BigStat(label: "Time", value: a.formattedDuration, unit: "")
                                }
                                if let pace = a.paceSecondsPerKm {
                                    let min = Int(pace) / 60; let sec = Int(pace) % 60
                                    BigStat(label: "Pace", value: String(format: "%d:%02d", min, sec), unit: "/km")
                                }
                                if let elev = a.elevationMeters {
                                    BigStat(label: "Elevation", value: String(format: "%.0f", elev), unit: "m")
                                }
                                if let hr = a.heartRateAvg {
                                    BigStat(label: "Avg HR", value: "\(hr)", unit: "bpm")
                                }
                                if let cal = a.calories {
                                    BigStat(label: "Calories", value: "\(cal)", unit: "kcal")
                                }
                            }

                            if let notes = a.notes, !notes.isEmpty {
                                Divider()
                                Text(notes)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }

                            Divider()

                            // Reactions + Comments
                            VStack(alignment: .leading, spacing: 16) {
                                // Reaction buttons
                                HStack(spacing: 8) {
                                    ForEach([("❤️", "LIKE"), ("🔥", "FIRE"), ("👏", "CLAP")], id: \.1) { emoji, type in
                                        ReactionButton(
                                            emoji: emoji,
                                            type: type,
                                            current: localUserReaction,
                                            isReacting: isReacting,
                                            action: react
                                        )
                                    }

                                    if localReactionCount > 0 {
                                        Text("\(localReactionCount) reaction\(localReactionCount == 1 ? "" : "s")")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                            .padding(.leading, 4)
                                    }
                                }

                                // Comments button
                                Button {
                                    showComments = true
                                } label: {
                                    HStack {
                                        Image(systemName: "bubble")
                                        Text("\(a.commentCount ?? 0) comment\(a.commentCount == 1 ? "" : "s")")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.system(size: 15))
                                    .foregroundStyle(.primary)
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
                .navigationDestination(isPresented: $showComments) {
                    CommentsView(activityId: activityId)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            activity = try? await ActivityService.shared.fetchActivity(id: activityId)
            localReactionCount = activity?.reactionCount ?? 0
            localUserReaction = activity?.userReaction
            isLoading = false
        }
    }

    // MARK: - Reaction

    private func react(type: String) {
        guard !isReacting else { return }
        isReacting = true

        let wasReaction = localUserReaction
        if localUserReaction == type {
            localUserReaction = nil
            localReactionCount = max(0, localReactionCount - 1)
        } else {
            if localUserReaction == nil { localReactionCount += 1 }
            localUserReaction = type
        }

        Task {
            do {
                if wasReaction == type {
                    try await ActivityService.shared.removeReaction(activityId: activityId)
                } else {
                    try await ActivityService.shared.addReaction(activityId: activityId, type: type)
                }
            } catch {
                localUserReaction = wasReaction
                localReactionCount = activity?.reactionCount ?? 0
            }
            isReacting = false
        }
    }
}

// MARK: - BigStat

struct BigStat: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1)
                .foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 22, weight: .black))
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - RouteMapView

struct RouteMapView: UIViewRepresentable {
    let points: [Activity.RoutePoint]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isUserInteractionEnabled = false
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coords = points.map(\.coordinate)
        guard !coords.isEmpty else { return }
        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        map.addOverlay(polyline)
        map.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20),
            animated: false
        )
        map.delegate = context.coordinator
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let r = MKPolylineRenderer(overlay: overlay)
            r.strokeColor = .black
            r.lineWidth = 3
            return r
        }
    }
}
