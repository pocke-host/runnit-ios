import Foundation

@MainActor
final class PlanService: ObservableObject {
    static let shared = PlanService()
    private let api = APIClient.shared

    @Published var plans: [Plan] = []
    @Published var activePlan: Plan?

    private init() {}

    func fetchPlans() async throws {
        let result: [Plan] = try await api.request("/plans")
        plans = result
        activePlan = result.first { $0.isActive == true }
    }

    func fetchPlan(id: Int) async throws -> Plan {
        try await api.request("/plans/\(id)")
    }

    func activatePlan(id: Int) async throws {
        let plan: Plan = try await api.request("/plans/\(id)/activate", method: "PATCH")
        activePlan = plan
        if let idx = plans.firstIndex(where: { $0.id == id }) {
            plans[idx] = plan
        }
    }

    func completeWorkout(planId: Int, workoutId: Int) async throws {
        try await api.requestVoid("/plans/\(planId)/workouts/\(workoutId)/complete", method: "PATCH")
    }

    func uncompleteWorkout(planId: Int, workoutId: Int) async throws {
        try await api.requestVoid("/plans/\(planId)/workouts/\(workoutId)/uncomplete", method: "PATCH")
    }
}
