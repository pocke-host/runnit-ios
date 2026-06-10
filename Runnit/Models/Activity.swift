import Foundation
import CoreLocation

struct Activity: Codable, Identifiable {
    let id: Int
    let userId: Int?
    let userDisplayName: String?
    let userAvatarUrl: String?
    let activityType: String
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
    let userReaction: String?

    struct RoutePoint: Codable {
        let lat: Double
        let lng: Double
        let ele: Double?

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }

    // MARK: - Custom Decodable — maps FeedActivityDTO JSON

    private struct UserInfo: Decodable {
        let id: Int?
        let displayName: String?
        let avatarUrl: String?
    }

    private enum CodingKeys: String, CodingKey {
        case id, notes, calories, userReaction
        case user
        case sportType
        case durationSeconds
        case distanceMeters
        case elevationGain
        case averageHeartRate
        case averagePace
        case createdAt
        case commentCount
        case reactionCounts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id              = try c.decode(Int.self, forKey: .id)
        notes           = try c.decodeIfPresent(String.self, forKey: .notes)
        calories        = try c.decodeIfPresent(Int.self, forKey: .calories)
        activityType    = try c.decodeIfPresent(String.self, forKey: .sportType) ?? "RUN"
        durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds)
        paceSecondsPerKm = try c.decodeIfPresent(Double.self, forKey: .averagePace)
        heartRateAvg    = try c.decodeIfPresent(Int.self, forKey: .averageHeartRate)
        userReaction    = try c.decodeIfPresent(String.self, forKey: .userReaction)
        commentCount    = try c.decodeIfPresent(Int.self, forKey: .commentCount)

        // Backend sends Int meters — cast to Double for display math
        distanceMeters  = try c.decodeIfPresent(Int.self, forKey: .distanceMeters).map(Double.init)
        elevationMeters = try c.decodeIfPresent(Int.self, forKey: .elevationGain).map(Double.init)

        // Flatten nested user object
        let info        = try c.decodeIfPresent(UserInfo.self, forKey: .user)
        userId          = info?.id
        userDisplayName = info?.displayName
        userAvatarUrl   = info?.avatarUrl

        // Sum per-type counts into a single total
        let counts      = try c.decodeIfPresent([String: Int].self, forKey: .reactionCounts) ?? [:]
        reactionCount   = counts.values.reduce(0, +)

        // Date — uses the decoder's registered date strategy
        date            = try c.decodeIfPresent(Date.self, forKey: .createdAt)

        // Not in FeedActivityDTO
        title           = nil
        routePoints     = nil
    }

    // MARK: - Formatted helpers

    var formattedDistance: String {
        guard let m = distanceMeters else { return "—" }
        return String(format: "%.2f km", m / 1000)
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
        case "RIDE", "BIKE": return "bicycle"
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
