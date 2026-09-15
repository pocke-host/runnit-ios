import SwiftUI

struct StrengthJournalView: View {
    @StateObject private var service = TrainingHubService.shared
    @State private var selected = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section { Text("Strength is part of the plan, not an afterthought.").font(.title3.bold()).padding(.vertical, 8) }
                Section("LAST 28 DAYS") {
                    if let volume = service.volume {
                        HStack { Stat(label: "VOLUME", value: number(volume.totalVolume)); Stat(label: "SESSIONS", value: "\(volume.sessions ?? 0)"); Stat(label: "SETS", value: "\(volume.totalSets ?? 0)") }
                    } else { ProgressView() }
                }
                Section("EXERCISE") {
                    if service.exercises.isEmpty { Text("Log a strength activity to start your journal.").foregroundStyle(RunnitTheme.muted) }
                    else { Picker("Exercise", selection: $selected) { ForEach(service.exercises, id: \.self) { Text($0).tag($0) } }.onChange(of: selected) { _, value in Task { try? await service.selectExercise(value) } } }
                }
                Section("PERSONAL RECORD") {
                    if let prs = service.prs { Text("Max weight: \(number(prs.maxWeight))"); Text("Estimated 1RM: \(number(prs.estimatedOneRepMax))") }
                    else { Text("No PR yet for this exercise.").foregroundStyle(RunnitTheme.muted) }
                }
                Section("RECENT PROGRESS") { ForEach(service.history) { point in HStack { Text(point.date); Spacer(); Text(number(point.volume)).font(.headline) } } }
            }
            .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(RunnitTheme.canvas).navigationTitle("Strength journal")
            .task { do { try await service.fetchStrength(); selected = service.exercises.first ?? "" } catch let requestError { error = requestError.localizedDescription } }
            .alert("Strength", isPresented: .init(get: { error != nil }, set: { _ in error = nil })) { Button("OK", role: .cancel) {} } message: { Text(error ?? "") }
        }
    }
    private func number(_ value: Double?) -> String { guard let value else { return "—" }; return String(format: "%.0f", value) }
}

private struct Stat: View {
    let label: String
    let value: String
    var body: some View { VStack(alignment: .leading) { Text(label).font(.caption2.bold()); Text(value).font(.title3.bold()) }.frame(maxWidth: .infinity, alignment: .leading) }
}
