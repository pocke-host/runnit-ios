import Foundation

struct Plan: Codable, Identifiable {
    let id: Int
    let title: String
    let goal: String?
    let level: String?
    let weeks: Int?
    let isActive: Bool?
    let startDate: String?
    let targetRaceDate: String?
    let workouts: [PlanWorkout]?
}

struct PlanWorkout: Codable, Identifiable {
    let id: Int
    let weekNumber: Int?
    let dayOfWeek: String?
    let workoutType: String?
    let title: String?
    let description: String?
    let distanceMeters: Int?
    let durationMinutes: Int?
    let targetPaceSeconds: Int?
    let isCompleted: Bool?

    var typeColor: String {
        switch workoutType?.uppercased() {
        case "EASY":        return "#22c55e"
        case "TEMPO":       return "#f97316"
        case "INTERVAL":    return "#ef4444"
        case "LONG_RUN":    return "#8b5cf6"
        case "RECOVERY":    return "#06b6d4"
        default:            return "#767676"
        }
    }
}
