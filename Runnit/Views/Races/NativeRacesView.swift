import SwiftUI

struct NativeRacesView: View {
    @StateObject private var service = TrainingHubService.shared
    @State private var tab = 0
    @State private var error: String?
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Races", selection: $tab) { Text("Discover").tag(0); Text("My races").tag(1) }
                    .pickerStyle(.segmented).padding(16)
                if tab == 0 { discover } else { saved }
            }
            .navigationTitle("Races").navigationBarTitleDisplayMode(.large).background(RunnitTheme.canvas)
            .task { await load() }
            .refreshable { await load() }
            .alert("Races", isPresented: .init(get: { error != nil }, set: { _ in error = nil })) { Button("OK", role: .cancel) {} } message: { Text(error ?? "") }
        }
    }
    private var discover: some View {
        Group { if service.races.isEmpty { ContentUnavailableView("No live races", systemImage: "flag", description: Text("Race discovery is temporarily unavailable. Try again soon.")) } else { List(service.races) { race in RaceCard(race: race, saved: service.bookmarks.contains { $0.externalRaceId == race.id }) { Task { do { try await service.bookmark(race) } catch { self.error = error.localizedDescription } } } } .listStyle(.plain).scrollContentBackground(.hidden) } }
    }
    private var saved: some View { List { if service.bookmarks.isEmpty && service.results.isEmpty { ContentUnavailableView("Your race story starts here", systemImage: "trophy", description: Text("Bookmark a goal race or connect an official result.")) } else { Section("BOOKMARKED") { ForEach(service.bookmarks) { b in VStack(alignment: .leading, spacing: 5) { Text(b.raceName).font(.headline); Text([b.raceDate, b.city].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(RunnitTheme.muted) }.padding(.vertical, 5).swipeActions { Button(role: .destructive) { Task { try? await service.removeBookmark(b.id) } } label: { Label("Remove", systemImage: "trash") } } } } ; Section("OFFICIAL RESULTS") { ForEach(service.results) { r in HStack { Image(systemName: r.verified ? "checkmark.seal.fill" : "flag").foregroundStyle(RunnitTheme.signal); VStack(alignment: .leading) { Text(r.raceName).font(.headline); Text("\(r.source ?? "Official") · \(r.distance ?? "Race")").font(.caption).foregroundStyle(RunnitTheme.muted) }; Spacer(); if let place = r.placement { Text("#\(place)").font(.system(.headline, design: .rounded)) } } } } } }.listStyle(.plain).scrollContentBackground(.hidden).background(RunnitTheme.canvas) }
    private func load() async { do { try await service.fetchRaces(); try await service.fetchRaceData() } catch let requestError { error = requestError.localizedDescription } }
}

private struct RaceCard: View { let race: RaceListing; let saved: Bool; let onSave: () -> Void; var body: some View { VStack(alignment: .leading, spacing: 10) { HStack { Text(race.sport?.uppercased() ?? "RUNNING").font(.caption.bold()).foregroundStyle(RunnitTheme.signal); Spacer(); Button(action: onSave) { Image(systemName: saved ? "bookmark.fill" : "bookmark").foregroundStyle(saved ? RunnitTheme.signal : RunnitTheme.ink) }.disabled(saved) }; Text(race.name).font(.headline); Text([race.date, [race.city, race.state].compactMap { $0 }.joined(separator: ", ")].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(RunnitTheme.muted) }.padding(16).background(Color.white).overlay(Rectangle().stroke(RunnitTheme.rule)) } }
