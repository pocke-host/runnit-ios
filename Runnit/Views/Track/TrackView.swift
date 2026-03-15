import SwiftUI
import MapKit

struct TrackView: View {
    @StateObject private var location = LocationService.shared
    @StateObject private var activityService = ActivityService.shared
    @EnvironmentObject private var auth: AuthService

    @State private var selectedType = "RUN"
    @State private var showSaveSheet = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let activityTypes = ["RUN", "RIDE", "WALK", "HIKE", "SWIM"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Permission gate
                if location.authorizationStatus == .notDetermined {
                    permissionView
                } else if location.authorizationStatus == .denied || location.authorizationStatus == .restricted {
                    deniedView
                } else {
                    trackingContent
                }
            }
            .navigationTitle("Track")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showSaveSheet) {
                SaveActivitySheet(
                    location: location,
                    type: selectedType,
                    isSaving: $isSaving,
                    onSave: saveActivity,
                    onDiscard: discardSession
                )
            }
        }
    }

    // MARK: - Main tracking UI

    private var trackingContent: some View {
        VStack(spacing: 0) {
            // Live map
            TrackMapView(location: location)
                .frame(maxHeight: .infinity)

            // Stats + controls
            VStack(spacing: 20) {
                // Type picker (only shown when not tracking)
                if !location.isTracking {
                    Picker("Type", selection: $selectedType) {
                        ForEach(activityTypes, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                // Live stats
                HStack(spacing: 0) {
                    LiveStat(label: "DISTANCE", value: String(format: "%.2f km", location.distanceMeters / 1000))
                    Divider().frame(height: 40)
                    LiveStat(label: "TIME", value: formatElapsed(location.elapsedSeconds))
                    Divider().frame(height: 40)
                    LiveStat(label: "PACE", value: formatPace(location.currentPaceSecPerKm))
                }
                .frame(maxWidth: .infinity)

                // Start / Stop button
                Button(action: toggleTracking) {
                    Text(location.isTracking ? "STOP" : "START")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(3)
                        .frame(width: 120, height: 120)
                        .background(location.isTracking ? Color.red : Color.black)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .padding(.bottom, 20)
            }
            .padding(.top, 16)
            .background(.white)
        }
    }

    // MARK: - Permission views

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle")
                .font(.system(size: 60))
                .foregroundStyle(.black)
            Text("Location Access")
                .font(.system(size: 24, weight: .black))
            Text("Runnit needs your location to track distance, pace, and route.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Enable Location") { location.requestPermission() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(40)
    }

    private var deniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash")
                .font(.system(size: 60))
            Text("Location Disabled")
                .font(.system(size: 24, weight: .black))
            Text("Enable location access in Settings → Runnit.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(40)
    }

    // MARK: - Actions

    private func toggleTracking() {
        if location.isTracking {
            location.stopTracking()
            showSaveSheet = true
        } else {
            location.startTracking()
        }
    }

    private func saveActivity(title: String?) async {
        isSaving = true
        let body = location.buildActivityBody(type: selectedType, title: title)
        do {
            let saved = try await activityService.createActivity(body)
            activityService.feed.insert(saved, at: 0)
            showSaveSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func discardSession() {
        location.trackPoints = []
        location.distanceMeters = 0
        location.elapsedSeconds = 0
        showSaveSheet = false
    }

    // MARK: - Formatting

    private func formatElapsed(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private func formatPace(_ secPerKm: Double) -> String {
        guard secPerKm > 0 && secPerKm < 3600 else { return "—" }
        return String(format: "%d:%02d", Int(secPerKm) / 60, Int(secPerKm) % 60)
    }
}

// MARK: - Sub-components

struct LiveStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .black))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}

struct SaveActivitySheet: View {
    let location: LocationService
    let type: String
    @Binding var isSaving: Bool
    let onSave: (String?) async -> Void
    let onDiscard: () -> Void

    @State private var title = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Summary stats
                HStack(spacing: 0) {
                    LiveStat(label: "DISTANCE", value: String(format: "%.2f km", location.distanceMeters / 1000))
                    LiveStat(label: "TIME", value: formatElapsed(location.elapsedSeconds))
                }
                .padding(.top, 8)

                RunnitTextField(label: "TITLE (OPTIONAL)", text: $title)
                    .padding(.horizontal)

                Button(action: { Task { await onSave(title.isEmpty ? nil : title) }}) {
                    ZStack {
                        if isSaving { ProgressView().tint(.white) }
                        else { Text("SAVE RUN").font(.system(size: 13, weight: .semibold)).tracking(2) }
                    }
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(.black).foregroundStyle(.white)
                }
                .padding(.horizontal)
                .disabled(isSaving)

                Button("Discard", role: .destructive, action: onDiscard)
                    .padding(.bottom)

                Spacer()
            }
            .navigationTitle("Save Activity")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatElapsed(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}

struct TrackMapView: UIViewRepresentable {
    @ObservedObject var location: LocationService

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.showsUserLocation = true
        map.userTrackingMode = .followWithHeading
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        let coords = location.trackPoints.map(\.coordinate)
        guard coords.count > 1 else { return }
        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        map.addOverlay(polyline)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let r = MKPolylineRenderer(overlay: overlay)
            r.strokeColor = .black
            r.lineWidth = 4
            return r
        }
    }
}
