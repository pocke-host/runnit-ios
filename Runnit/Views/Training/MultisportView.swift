import SwiftUI

struct MultisportView: View {
    @StateObject private var service = MultisportService.shared
    @StateObject private var activityService = ActivityService.shared
    @State private var showingCreate = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                if service.events.isEmpty {
                    ContentUnavailableView("Combine a multisport day", systemImage: "figure.mixed.cardio", description: Text("Group swim, bike, run, or strength activities into one event."))
                } else {
                    ForEach(service.events) { event in
                        HStack { Image(systemName: "figure.mixed.cardio").foregroundStyle(RunnitTheme.signal); VStack(alignment: .leading) { Text(event.name).font(.headline); Text("\(event.segmentCount) segments · \(String(format: "%.1f", Double(event.totalDistanceMeters) / 1000)) km").font(.caption).foregroundStyle(RunnitTheme.muted) }; Spacer(); Text(duration(event.totalDurationSeconds)).font(.caption.bold()) }
                            .swipeActions { Button(role: .destructive) { Task { try? await service.delete(id: event.id) } } label: { Label("Delete", systemImage: "trash") } }
                    }
                }
            }
            .navigationTitle("Multisport")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingCreate = true } label: { Image(systemName: "plus") } } }
            .background(RunnitTheme.canvas)
            .task { do { try await service.fetch(); try? await activityService.fetchMyActivities() } catch let requestError { error = requestError.localizedDescription } }
            .sheet(isPresented: $showingCreate) { CombineActivitiesSheet(service: service, activities: activityService.myActivities) }
            .alert("Multisport", isPresented: .init(get: { error != nil }, set: { _ in error = nil })) { Button("OK", role: .cancel) {} } message: { Text(error ?? "") }
        }
    }
    private func duration(_ seconds: Int) -> String { "\(seconds / 3600):\(String(format: "%02d", (seconds % 3600) / 60))" }
}

private struct CombineActivitiesSheet: View {
    @ObservedObject var service: MultisportService
    let activities: [Activity]
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Triathlon day"
    @State private var selected = Set<Int>()
    var body: some View {
        NavigationStack {
            List {
                TextField("Event name", text: $name)
                Section("SELECT ACTIVITIES") {
                    ForEach(activities) { activity in
                        Button {
                            if selected.contains(activity.id) { selected.remove(activity.id) } else { selected.insert(activity.id) }
                        } label: {
                            HStack { Image(systemName: selected.contains(activity.id) ? "checkmark.circle.fill" : "circle"); Text(activity.title ?? activity.activityType.capitalized); Spacer(); Text(activity.formattedDistance).font(.caption) }
                        }
                    }
                }
            }
            .navigationTitle("Combine activities")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { try? await service.create(name: name, type: "MULTISPORT", date: nil, activityIds: Array(selected)); dismiss() } }.disabled(selected.isEmpty) }
            }
        }
    }
}
