import SwiftUI
import MapKit

struct ActivityDetailView: View {
    let activityId: Int
    @State private var activity: Activity?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let a = activity {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Map
                        if let points = a.routePoints, !points.isEmpty {
                            RouteMapView(points: points)
                                .frame(height: 260)
                        }

                        VStack(alignment: .leading, spacing: 20) {
                            // Title + type
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
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                                if let d = a.distanceMeters {
                                    BigStat(label: "Distance", value: String(format: "%.2f", d / 1000), unit: "km")
                                }
                                if let dur = a.durationSeconds {
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
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            activity = try? await ActivityService.shared.fetchActivity(id: activityId)
            isLoading = false
        }
    }
}

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
        map.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), animated: false)
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
