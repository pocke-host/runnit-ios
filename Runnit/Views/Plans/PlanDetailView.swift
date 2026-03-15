import SwiftUI

struct PlanDetailView: View {
    let planId: Int
    @State private var plan: Plan?
    @State private var isLoading = true
    @State private var expandedWeeks: Set<Int> = [1]

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let plan {
                planContent(plan)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            plan = try? await PlanService.shared.fetchPlan(id: planId)
            isLoading = false
            // Auto-expand current week
            if let workouts = plan?.workouts, let currentWeek = currentWeek(workouts) {
                expandedWeeks = [currentWeek]
            }
        }
    }

    private func planContent(_ plan: Plan) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                // Hero
                VStack(alignment: .leading, spacing: 8) {
                    if plan.isActive == true {
                        Text("ACTIVE PLAN")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text(plan.title)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)
                    HStack(spacing: 16) {
                        if let goal = plan.goal { Label(goal, systemImage: "flag").font(.system(size: 13)) }
                        if let weeks = plan.weeks { Label("\(weeks) wks", systemImage: "calendar").font(.system(size: 13)) }
                        if let level = plan.level { Label(level, systemImage: "chart.bar").font(.system(size: 13)) }
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.black)

                // Workouts by week
                if let workouts = plan.workouts {
                    let weeks = Dictionary(grouping: workouts) { $0.weekNumber ?? 0 }
                    let sortedWeeks = weeks.keys.sorted()

                    ForEach(sortedWeeks, id: \.self) { week in
                        WeekSection(
                            week: week,
                            workouts: weeks[week] ?? [],
                            planId: plan.id,
                            isExpanded: expandedWeeks.contains(week),
                            onToggle: {
                                if expandedWeeks.contains(week) { expandedWeeks.remove(week) }
                                else { expandedWeeks.insert(week) }
                            }
                        )
                    }
                }
            }
        }
    }

    private func currentWeek(_ workouts: [PlanWorkout]) -> Int? {
        workouts.first(where: { $0.isCompleted == false })?.weekNumber
    }
}

struct WeekSection: View {
    let week: Int
    let workouts: [PlanWorkout]
    let planId: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    var completedCount: Int { workouts.filter { $0.isCompleted == true }.count }

    var body: some View {
        VStack(spacing: 0) {
            // Week header
            Button(action: onToggle) {
                HStack {
                    Text("WEEK \(week)")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(2)
                    Spacer()
                    Text("\(completedCount)/\(workouts.count)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(workouts) { workout in
                    WorkoutRow(workout: workout, planId: planId)
                    Divider().padding(.leading, 20)
                }
            }
        }
    }
}

struct WorkoutRow: View {
    let workout: PlanWorkout
    let planId: Int
    @State private var isCompleted: Bool

    init(workout: PlanWorkout, planId: Int) {
        self.workout = workout
        self.planId = planId
        _isCompleted = State(initialValue: workout.isCompleted ?? false)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Completion toggle
            Button(action: toggleComplete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isCompleted ? .black : Color(.systemGray3))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if let type = workout.workoutType {
                        Text(type.replacingOccurrences(of: "_", with: " "))
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(hex: workout.typeColor).opacity(0.15))
                            .foregroundStyle(Color(hex: workout.typeColor))
                    }
                    if let day = workout.dayOfWeek {
                        Text(day)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(workout.title ?? workout.workoutType ?? "Workout")
                    .font(.system(size: 15, weight: .semibold))
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? .secondary : .primary)

                if let desc = workout.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    if let dist = workout.distanceMeters {
                        Label(String(format: "%.1f km", Double(dist) / 1000), systemImage: "arrow.right")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    if let dur = workout.durationMinutes {
                        Label("\(dur) min", systemImage: "clock")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.white)
    }

    private func toggleComplete() {
        isCompleted.toggle()
        Task {
            do {
                if isCompleted {
                    try await PlanService.shared.completeWorkout(planId: planId, workoutId: workout.id)
                } else {
                    try await PlanService.shared.uncompleteWorkout(planId: planId, workoutId: workout.id)
                }
            } catch {
                isCompleted.toggle() // revert on failure
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
