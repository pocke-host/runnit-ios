import Foundation
import HealthKit

struct AppleHealthStatus: Decodable {
    let connected: Bool
    let lastSync: String?
}

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    @Published var status: AppleHealthStatus?
    @Published var isLoading = false
    @Published var isSyncing = false

    private let store = HKHealthStore()
    private let api = APIClient.shared

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func fetchStatus() async {
        isLoading = true
        defer { isLoading = false }
        do {
            status = try await api.request("/integrations/apple-health/status")
        } catch {
            print("[HealthKit] fetchStatus failed: \(error.localizedDescription)")
        }
    }

    func connectAndSync() async throws -> Int {
        guard isAvailable else { throw HealthKitError.unavailable }
        isLoading = true
        defer { isLoading = false }

        let workoutType = HKObjectType.workoutType()
        try await store.requestAuthorization(toShare: [], read: [workoutType])
        try await api.requestVoid("/integrations/apple-health/connect", method: "POST")
        let imported = try await syncRecentWorkouts()
        await fetchStatus()
        return imported
    }

    func syncRecentWorkouts() async throws -> Int {
        guard isAvailable else { throw HealthKitError.unavailable }
        isSyncing = true
        defer { isSyncing = false }

        let since = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date.distantPast
        let workouts = try await fetchWorkouts(since: since)
        let samples = workouts.map(Self.payload)
        struct Body: Encodable { let samples: [AppleHealthSample] }
        struct Response: Decodable { let imported: Int }
        let response: Response = try await api.request(
            "/integrations/apple-health/sync",
            method: "POST",
            body: Body(samples: samples)
        )
        await fetchStatus()
        return response.imported
    }

    func disconnect() async throws {
        try await api.requestVoid("/integrations/apple-health/disconnect", method: "DELETE")
        status = AppleHealthStatus(connected: false, lastSync: nil)
    }

    private func fetchWorkouts(since: Date) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 200,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    private static func payload(_ workout: HKWorkout) -> AppleHealthSample {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return AppleHealthSample(
            externalId: workout.uuid.uuidString,
            sportType: sportType(for: workout.workoutActivityType),
            durationSeconds: Int(workout.duration.rounded()),
            distanceMeters: workout.totalDistance?.doubleValue(for: .meter()).map { Int($0.rounded()) },
            calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()).map { Int($0.rounded()) },
            performedAt: formatter.string(from: workout.startDate)
        )
    }

    private static func sportType(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "RUN"
        case .cycling: return "RIDE"
        case .swimming: return "SWIM"
        case .hiking: return "HIKE"
        case .walking: return "WALK"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "STRENGTH"
        default: return "OTHER"
        }
    }
}

struct AppleHealthSample: Encodable {
    let externalId: String
    let sportType: String
    let durationSeconds: Int
    let distanceMeters: Int?
    let calories: Int?
    let performedAt: String
}

enum HealthKitError: LocalizedError {
    case unavailable
    var errorDescription: String? { "Apple Health is not available on this device." }
}
