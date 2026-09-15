import SwiftUI

struct NativeRacesView: View {
    @StateObject private var service = TrainingHubService.shared
    @State private var tab = 0
    @State private var error: String?
    @State private var showingImport = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Races", selection: $tab) { Text("Discover").tag(0); Text("My races").tag(1) }
                    .pickerStyle(.segmented).padding(16)
                if tab == 0 { discover } else { saved }
            }
            .navigationTitle("Races").navigationBarTitleDisplayMode(.large).background(RunnitTheme.canvas)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Import result") { showingImport = true } } }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showingImport) { RaceResultImportView(service: service) }
            .alert("Races", isPresented: .init(get: { error != nil }, set: { _ in error = nil })) { Button("OK", role: .cancel) {} } message: { Text(error ?? "") }
        }
    }
    private var discover: some View {
        Group { if service.races.isEmpty { ContentUnavailableView("No live races", systemImage: "flag", description: Text("Race discovery is temporarily unavailable. Try again soon.")) } else { List(service.races) { race in RaceCard(race: race, saved: service.bookmarks.contains { $0.externalRaceId == race.id }) { Task { do { try await service.bookmark(race) } catch { self.error = error.localizedDescription } } } } .listStyle(.plain).scrollContentBackground(.hidden) } }
    }
    private var saved: some View { List { if service.bookmarks.isEmpty && service.results.isEmpty { ContentUnavailableView("Your race story starts here", systemImage: "trophy", description: Text("Bookmark a goal race or connect an official result.")) } else { Section("BOOKMARKED") { ForEach(service.bookmarks) { b in VStack(alignment: .leading, spacing: 5) { Text(b.raceName).font(.headline); Text([b.raceDate, b.city].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(RunnitTheme.muted) }.padding(.vertical, 5).swipeActions { Button(role: .destructive) { Task { try? await service.removeBookmark(b.id) } } label: { Label("Remove", systemImage: "trash") } } } } ; Section("OFFICIAL RESULTS") { ForEach(service.results) { r in HStack { Image(systemName: r.verified ? "checkmark.seal.fill" : "flag").foregroundStyle(RunnitTheme.signal); VStack(alignment: .leading) { Text(r.raceName).font(.headline); Text("\(r.source ?? "Official") · \(r.distance ?? "Race")").font(.caption).foregroundStyle(RunnitTheme.muted) }; Spacer(); if let place = r.placement { Text("#\(place)").font(.system(.headline, design: .rounded)) } } } } } }.listStyle(.plain).scrollContentBackground(.hidden).background(RunnitTheme.canvas) }
    private func load() async { do { try await service.fetchRaces(); try await service.fetchRaceData() } catch let requestError { error = requestError.localizedDescription } }
}

private struct RaceResultImportView: View {
    @ObservedObject var service: TrainingHubService
    @Environment(\.dismiss) private var dismiss
    @State private var provider = "ATHLINKS"
    @State private var raceId = ""
    @State private var eventId = ""
    @State private var candidates: [OfficialResultCandidate] = []
    @State private var isSearching = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("1 · CHOOSE PROVIDER") {
                    Picker("Timing provider", selection: $provider) { Text("Athlinks").tag("ATHLINKS"); Text("RunSignup").tag("RUNSIGNUP") }
                    if provider == "RUNSIGNUP" { TextField("Race ID (optional)", text: $raceId); TextField("Event ID (optional)", text: $eventId) }
                }
                Section("2 · FIND RESULTS") {
                    Button(isSearching ? "Searching…" : "Find my official results") { Task { await search() } }.disabled(isSearching)
                    ForEach(candidates) { candidate in
                        HStack { VStack(alignment: .leading) { Text(candidate.raceName).font(.headline); Text("\(candidate.raceDate ?? "Date TBD") · \(candidate.distance ?? "Race") · \(candidate.provider)").font(.caption).foregroundStyle(RunnitTheme.muted) }; Spacer(); Button("Save") { Task { do { try await service.importResult(candidate); message = "Result saved." } catch { message = error.localizedDescription } } }.buttonStyle(.borderedProminent).tint(RunnitTheme.signal) }
                    }
                }
            }
            .navigationTitle("Official result")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .alert("Race result", isPresented: .init(get: { message != nil }, set: { _ in message = nil })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
        }
    }
    private func search() async { isSearching = true; defer { isSearching = false }; do { candidates = try await service.discoverResults(provider: provider, raceId: raceId.isEmpty ? nil : raceId, eventId: eventId.isEmpty ? nil : eventId) } catch { message = error.localizedDescription } }
}

private struct RaceCard: View { let race: RaceListing; let saved: Bool; let onSave: () -> Void; var body: some View { VStack(alignment: .leading, spacing: 10) { HStack { Text(race.sport?.uppercased() ?? "RUNNING").font(.caption.bold()).foregroundStyle(RunnitTheme.signal); Spacer(); Button(action: onSave) { Image(systemName: saved ? "bookmark.fill" : "bookmark").foregroundStyle(saved ? RunnitTheme.signal : RunnitTheme.ink) }.disabled(saved) }; Text(race.name).font(.headline); Text([race.date, [race.city, race.state].compactMap { $0 }.joined(separator: ", ")].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(RunnitTheme.muted) }.padding(16).background(Color.white).overlay(Rectangle().stroke(RunnitTheme.rule)) } }
