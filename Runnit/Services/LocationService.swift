import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isTracking = false

    // Live session data
    @Published var trackPoints: [CLLocation] = []
    @Published var distanceMeters: Double = 0
    @Published var elapsedSeconds: Int = 0
    @Published var currentPaceSecPerKm: Double = 0

    private let manager = CLLocationManager()
    private var timer: AnyCancellable?
    private var sessionStart: Date?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5  // update every 5 meters
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Permissions

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    // MARK: - Session control

    func startTracking() {
        trackPoints = []
        distanceMeters = 0
        elapsedSeconds = 0
        currentPaceSecPerKm = 0
        sessionStart = Date()
        isTracking = true

        manager.startUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.sessionStart else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(start))
            }
    }

    func stopTracking() {
        isTracking = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        timer?.cancel()
        timer = nil
    }

    // MARK: - Build save body

    func buildActivityBody(type: String, title: String?) -> CreateActivityBody {
        let dateStr = ISO8601DateFormatter().string(from: sessionStart ?? Date())
        let points = trackPoints.map {
            CreateActivityBody.RoutePointBody(lat: $0.coordinate.latitude, lng: $0.coordinate.longitude, ele: $0.altitude)
        }
        return CreateActivityBody(
            activityType: type,
            title: title,
            notes: nil,
            distanceMeters: distanceMeters,
            durationSeconds: elapsedSeconds,
            elevationMeters: totalElevationGain(),
            heartRateAvg: nil,
            calories: estimateCalories(),
            date: dateStr,
            routePoints: points
        )
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for loc in locations {
                guard loc.horizontalAccuracy < 20 else { continue }

                if let last = trackPoints.last {
                    distanceMeters += loc.distance(from: last)
                    // Pace: seconds per km over last segment
                    let segDist = loc.distance(from: last)
                    let segTime = loc.timestamp.timeIntervalSince(last.timestamp)
                    if segDist > 10 && segTime > 0 {
                        currentPaceSecPerKm = (segTime / segDist) * 1000
                    }
                }
                trackPoints.append(loc)
                currentLocation = loc
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.authorizationStatus = manager.authorizationStatus }
    }

    // MARK: - Calculations

    private func totalElevationGain() -> Double {
        var gain = 0.0
        for i in 1..<trackPoints.count {
            let diff = trackPoints[i].altitude - trackPoints[i - 1].altitude
            if diff > 0 { gain += diff }
        }
        return gain
    }

    private func estimateCalories() -> Int {
        // ~60 cal/km as rough estimate
        Int((distanceMeters / 1000) * 60)
    }
}
