import SwiftUI

struct NativeCalendarView: View {
    @StateObject private var service = TrainingHubService.shared
    @State private var selected = Date()
    @State private var error: String?
    @State private var editingEvent: WorkoutEvent?
    private let calendar = Calendar.current
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weekPicker
                Divider()
                if service.events.isEmpty { ContentUnavailableView("Your calendar is clear", systemImage: "calendar", description: Text("Planned workouts from your plan will appear here.")) }
                else { List(service.events) { event in eventRow(event) }.listStyle(.plain).scrollContentBackground(.hidden) }
            }
            .background(RunnitTheme.canvas).navigationTitle("Calendar").navigationBarTitleDisplayMode(.large)
            .task { await load() }.onChange(of: selected) { _, _ in Task { await load() } }
            .sheet(item: $editingEvent) { event in CalendarEventEditSheet(service: service, event: event) }
            .alert("Calendar", isPresented: .init(get: { error != nil }, set: { _ in error = nil })) { Button("OK", role: .cancel) {} } message: { Text(error ?? "") }
        }
    }
    private var weekPicker: some View {
        HStack { ForEach(0..<7, id: \.self) { offset in let date = calendar.date(byAdding: .day, value: offset - 3, to: selected) ?? selected; Button { selected = date } label: { VStack(spacing: 5) { Text(date, format: .dateTime.weekday(.narrow)); Text(date, format: .dateTime.day()).font(.headline) }.frame(maxWidth: .infinity).padding(.vertical, 10).background(calendar.isDate(date, inSameDayAs: selected) ? RunnitTheme.signal : Color.clear).foregroundStyle(calendar.isDate(date, inSameDayAs: selected) ? .white : RunnitTheme.ink) }.dropDestination(for: String.self) { ids, _ in let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; for id in ids { if let eventId = Int(id) { Task { try? await service.reschedule(eventId: eventId, to: formatter.string(from: date)) } } }; return true } } }.padding(.horizontal, 10).background(Color.white)
    }
    private func eventRow(_ event: WorkoutEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { Task { try? await service.updateCalendarEvent(id: event.id, completed: !event.completed) } } label: { Image(systemName: event.completed ? "checkmark.circle.fill" : "circle").foregroundStyle(event.completed ? .green : RunnitTheme.signal) }.accessibilityLabel(event.completed ? "Mark incomplete" : "Mark complete")
            VStack(alignment: .leading, spacing: 4) { Text(event.title).font(.headline); Text([event.workoutType, event.distanceMeters.map { "\(String(format: "%.1f", Double($0) / 1000)) km" }, event.durationMinutes.map { "\($0) min" }].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(RunnitTheme.muted); if let description = event.description { Text(description).font(.caption2).foregroundStyle(RunnitTheme.muted) } }.padding(.vertical, 7)
        }.contentShape(Rectangle()).onTapGesture { editingEvent = event }.draggable(String(event.id)).swipeActions { Button(role: .destructive) { Task { try? await service.deleteCalendarEvent(id: event.id) } } label: { Label("Delete", systemImage: "trash") } }
    }
    private func load() async { let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; let start = calendar.date(byAdding: .day, value: -3, to: selected)!; let end = calendar.date(byAdding: .day, value: 3, to: selected)!; do { try await service.fetchCalendar(start: formatter.string(from: start), end: formatter.string(from: end)) } catch let requestError { error = requestError.localizedDescription } }
}

private struct CalendarEventEditSheet: View {
    @ObservedObject var service: TrainingHubService
    let event: WorkoutEvent
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date
    @State private var completed: Bool
    init(service: TrainingHubService, event: WorkoutEvent) { self.service = service; self.event = event; _title = State(initialValue: event.title); _completed = State(initialValue: event.completed); let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; _date = State(initialValue: formatter.date(from: event.plannedDate) ?? Date()) }
    var body: some View { NavigationStack { Form { TextField("Workout title", text: $title); DatePicker("Planned date", selection: $date, displayedComponents: .date); Toggle("Completed", isOn: $completed) }.navigationTitle("Edit workout").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; Task { try? await service.updateCalendarEvent(id: event.id, completed: completed, title: title, plannedDate: formatter.string(from: date)); dismiss() } } } } } }
}
