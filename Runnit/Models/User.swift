import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let user: String           // username / handle
    let displayName: String
    let avatarUrl: String?
    let bio: String?
    let sport: String?
    let location: String?
    let unitSystem: String?    // "imperial" | "metric"
    let role: String?
    let isPublic: Bool?
    let onboardingComplete: Bool?

    var usesImperial: Bool { unitSystem == "imperial" }
    var avatarURL: URL? { avatarUrl.flatMap(URL.init) }
}
