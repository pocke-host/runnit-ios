import Foundation
import CoreLocation

struct Activity: Codable, Identifiable {
    let id: Int
    let userId: Int?
    let userDisplayName: String?
    let userAvatarUrl: String?
    let activityType: String       // "RUN", "RIDE", "SWIM", etc.
    let title: String?
    let notes: String?
    let distanceMeters: Double?
    let durationSeconds: Int?
    let elevationMeters: Double?
    let heartRateAvg: Int?
    let calories: Int?
    let paceSecondsPerKm: Double?
    let date: Date?
    let routePoints: [RoutePoint]?
    let reactionCount: Int?
    let commentCount: Int?

    struct RoutePoint: Codable {
        let lat: Double
        let lng: Double
        let ele: Double?

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }

    // MARK: - Formatted helpers

    var formattedDistance: String {
        guard let m = distanceMeters else { return "—" }
        let km = m / 1000
        return String(format: "%.2f km", km)
    }

    var formattedDuration: String {
        guard let s = durationSeconds else { return "—" }
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    var activityIcon: String {
        switch activityType.uppercased() {
        case "RUN":    return "figure.run"
        case "RIDE":   return "bicycle"
        case "SWIM":   return "figure.pool.swim"
        case "WALK":   return "figure.walk"
        case "HIKE":   return "mountain.2"
        default:       return "sportscourt"
        }
    }
}

// MARK: - Create request body

struct CreateActivityBody: Encodable {
    let activityType: String
    let title: String?
    let notes: String?
    let distanceMeters: Double?
    let durationSeconds: Int?
    let elevationMeters: Double?
    let heartRateAvg: Int?
    let calories: Int?
    let date: String
    let routePoints: [RoutePointBody]?

    struct RoutePointBody: Encodable {
        let lat: Double
        let lng: Double
        let ele: Double?
    }
}
