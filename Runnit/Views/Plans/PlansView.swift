import SwiftUI

struct PlansView: View {
    @StateObject private var service = PlanService.shared
    @State private var selectedPlan: Plan?

    var body: some View {
        NavigationStack {
            Group {
                if service.plans.isEmpty {
                    ContentUnavailableView("No training plans", systemImage: "calendar.badge.plus", description: Text("Create a plan on runnit.live to get started."))
                } else {
                    List {
                        if let active = service.activePlan {
                            Section("ACTIVE PLAN") {
                                PlanRow(plan: active)
                            }
                        }

                        let others = service.plans.filter { $0.id != service.activePlan?.id }
                        if !others.isEmpty {
                            Section("ALL PLANS") {
                                ForEach(others) { plan in
                                    NavigationLink(destination: PlanDetailView(planId: plan.id)) {
                                        PlanRow(plan: plan)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { try? await service.fetchPlans() }
                }
            }
            .navigationTitle("Training Plans")
            .task { try? await service.fetchPlans() }
        }
    }
}

struct PlanRow: View {
    let plan: Plan

    var body: some View {
        NavigationLink(destination: PlanDetailView(planId: plan.id)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plan.title)
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    if plan.isActive == true {
                        Text("ACTIVE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.black)
                            .foregroundStyle(.white)
                    }
                }
                HStack(spacing: 12) {
                    if let goal = plan.goal {
                        Label(goal, systemImage: "flag")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    if let weeks = plan.weeks {
                        Label("\(weeks) weeks", systemImage: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
