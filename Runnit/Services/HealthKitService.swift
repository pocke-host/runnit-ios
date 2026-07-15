import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    // UserDefaults key — tracks the last time we pulled from HealthKit so we
    // never re-upload the same workout twice
    private let lastSyncKey = "healthkit_last_sync_date"

    @Published var isAuthorized = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date? = UserDefaults.standard.object(forKey: "healthkit_last_sync_date") as? Date

    private var lastSyncedAt: Date {
        get { UserDefaults.standard.object(forKey: lastSyncKey) as? Date ?? Date.distantPast }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncKey) }
    }

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
        HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
    ]

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            return true
        } catch {
            print("[HealthKit] Authorization failed: \(error)")
            return false
        }
    }

    // MARK: - Initial sync (past 90 days on first run, incremental after)

    func syncWorkouts() async {
        guard HKHealthStore.isHealthDataAvailable(), !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let since = lastSyncedAt == .distantPast
            ? Calendar.current.date(byAdding: .day, value: -90, to: Date())!
            : lastSyncedAt

        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        do {
            let workouts = try await fetchWorkouts(predicate: predicate, sort: sort)
            print("[HealthKit] Found \(workouts.count) workouts since \(since)")

            var uploaded = 0
            for workout in workouts {
                let body = await buildActivityBody(from: workout)
                do {
                    _ = try await ActivityService.shared.createActivity(body)
                    uploaded += 1
                } catch {
                    print("[HealthKit] Upload failed for workout \(workout.uuid): \(error)")
                }
            }

            lastSyncedAt = Date()
            lastSyncDate = lastSyncedAt
            print("[HealthKit] Synced \(uploaded)/\(workouts.count) workouts")
        } catch {
            print("[HealthKit] Sync failed: \(error)")
        }
    }

    // MARK: - Background observer — fires when a new workout is saved

    func startBackgroundObserver() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let workoutType = HKObjectType.workoutType()

        store.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { success, error in
            if !success { print("[HealthKit] Background delivery enable failed: \(String(describing: error))") }
        }

        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, _, error in
            guard error == nil else { return }
            Task { await self?.syncWorkouts() }
        }
        store.execute(query)
    }

    // MARK: - Private helpers

    private func fetchWorkouts(predicate: NSPredicate, sort: NSSortDescriptor) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    private func fetchAverageHeartRate(start: Date, end: Date) async -> Int? {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                let bpm = stats?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm.map { Int($0) })
            }
            store.execute(query)
        }
    }

    private func buildActivityBody(from workout: HKWorkout) async -> CreateActivityBody {
        let sportType = mapWorkoutType(workout.workoutActivityType)
        let distanceM = workout.totalDistance?.doubleValue(for: .meter())
        let calories  = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()).map { Int($0) }
        let heartRate = await fetchAverageHeartRate(start: workout.startDate, end: workout.endDate)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return CreateActivityBody(
            activityType:    sportType,
            title:           workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String ?? "\(sportType.capitalized) via Apple Health",
            notes:           nil,
            distanceMeters:  distanceM,
            durationSeconds: Int(workout.duration),
            elevationMeters: nil,
            heartRateAvg:    heartRate,
            calories:        calories,
            date:            formatter.string(from: workout.startDate),
            source:          "APPLE_HEALTH",
            externalId:      workout.uuid.uuidString,
            routePoints:     nil
        )
    }

    private func mapWorkoutType(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:                      return "RUN"
        case .cycling:                      return "RIDE"
        case .swimming:                     return "SWIM"
        case .walking:                      return "WALK"
        case .hiking:                       return "HIKE"
        case .rowing:                       return "ROW"
        case .crossTraining, .functionalStrengthTraining,
             .traditionalStrengthTraining:  return "STRENGTH"
        case .yoga:                         return "YOGA"
        case .skiing, .snowboarding:        return "SKI"
        default:                            return "WORKOUT"
        }
    }
}
