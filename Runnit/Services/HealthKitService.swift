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
    @Published var automaticSyncEnabled = false
    @Published var lastError: String?

    private let store = HKHealthStore()
    private let api = APIClient.shared
    private let anchorKey = "runnit.healthkit.workout-anchor"
    private var observerQuery: HKObserverQuery?

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Registers the observer that lets HealthKit wake RUNNIT after Apple Watch
    /// workouts arrive in the iPhone's Health store. This is safe to call at
    /// every app launch; the query is only installed once per process.
    func startAutomaticSync() {
        guard isAvailable else { return }

        if observerQuery == nil {
            let workoutType = HKObjectType.workoutType()
            let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completion, error in
                Task { @MainActor [weak self] in
                    defer { completion() }
                    guard let self else { return }
                    if let error {
                        self.lastError = error.localizedDescription
                        return
                    }

                    do {
                        _ = try await self.syncNewWorkouts()
                    } catch {
                        // HealthKit will deliver another observer callback later;
                        // keeping the anchor unchanged makes this retry-safe.
                        self.lastError = error.localizedDescription
                    }
                }
            }

            observerQuery = query
            store.execute(query)
        }

        // Re-enable delivery after authorization is granted as well as at launch.
        // HealthKit may reject the first call when the app has not been authorized yet.
        let workoutType = HKObjectType.workoutType()
        store.enableBackgroundDelivery(for: workoutType, frequency: .hourly) { [weak self] success, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.automaticSyncEnabled = success
                if let error {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    func stopAutomaticSync() {
        if let observerQuery {
            store.stop(observerQuery)
            self.observerQuery = nil
        }
        let workoutType = HKObjectType.workoutType()
        store.disableBackgroundDelivery(for: workoutType) { [weak self] _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.automaticSyncEnabled = false
                if let error {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

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
        startAutomaticSync()
        let imported = try await syncNewWorkouts(sinceDays: 90)
        await fetchStatus()
        return imported
    }

    func syncRecentWorkouts() async throws -> Int {
        guard isAvailable else { throw HealthKitError.unavailable }
        startAutomaticSync()
        let imported = try await syncNewWorkouts(sinceDays: 90)
        await fetchStatus()
        return imported
    }

    /// Pulls only workouts newer than the saved HealthKit anchor. The anchor is
    /// advanced only after the backend accepts the batch, so an offline or 5xx
    /// failure will be retried instead of silently losing the workout.
    @discardableResult
    func syncNewWorkouts(sinceDays: Int? = nil) async throws -> Int {
        guard isAvailable else { throw HealthKitError.unavailable }
        guard KeychainHelper.token != nil else { return 0 }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        let batch = try await fetchWorkoutBatch(sinceDays: sinceDays)
        let uniqueWorkouts = Dictionary(grouping: batch.workouts, by: { $0.uuid })
            .compactMap { $0.value.first }
        let samples = uniqueWorkouts.map(Self.payload)

        struct Body: Encodable { let samples: [AppleHealthSample] }
        struct Response: Decodable { let imported: Int }
        let response: Response = try await api.request(
            "/integrations/apple-health/sync",
            method: "POST",
            body: Body(samples: samples)
        )

        if let anchor = batch.anchor {
            saveAnchor(anchor)
        }
        await fetchStatus()
        return response.imported
    }

    func disconnect() async throws {
        stopAutomaticSync()
        clearAnchor()
        try await api.requestVoid("/integrations/apple-health/disconnect", method: "DELETE")
        status = AppleHealthStatus(connected: false, lastSync: nil)
    }

    private struct WorkoutBatch {
        let workouts: [HKWorkout]
        let anchor: HKQueryAnchor?
    }

    private func fetchWorkoutBatch(sinceDays: Int?) async throws -> WorkoutBatch {
        let predicate: NSPredicate?
        if let sinceDays {
            let since = Calendar.current.date(byAdding: .day, value: -sinceDays, to: Date()) ?? Date.distantPast
            predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        } else {
            predicate = nil
        }

        let anchor = loadAnchor()
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WorkoutBatch, Error>) in
            let query = HKAnchoredObjectQuery(
                type: .workoutType(),
                predicate: predicate,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, newAnchor, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: WorkoutBatch(
                    workouts: (samples as? [HKWorkout]) ?? [],
                    anchor: newAnchor
                ))
            }
            store.execute(query)
        }
    }

    private func loadAnchor() -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: anchorKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func saveAnchor(_ anchor: HKQueryAnchor) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else { return }
        UserDefaults.standard.set(data, forKey: anchorKey)
    }

    private func clearAnchor() {
        UserDefaults.standard.removeObject(forKey: anchorKey)
    }

    private static func payload(_ workout: HKWorkout) -> AppleHealthSample {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return AppleHealthSample(
            externalId: workout.uuid.uuidString,
            sportType: sportType(for: workout.workoutActivityType),
            durationSeconds: Int(workout.duration.rounded()),
            distanceMeters: workout.totalDistance.map { Int($0.doubleValue(for: .meter()).rounded()) },
            calories: workout.totalEnergyBurned.map { Int($0.doubleValue(for: .kilocalorie()).rounded()) },
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
