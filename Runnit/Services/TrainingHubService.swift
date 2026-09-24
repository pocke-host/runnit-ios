import Foundation

struct TrainingFolderItem: Codable, Identifiable {
    let id: Int
    let itemType: String
    let itemId: Int
}

struct TrainingFolder: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let color: String?
    let targetDate: String?
    let items: [TrainingFolderItem]
}

struct RaceBookmark: Codable, Identifiable {
    let id: Int
    let externalRaceId: String?
    let raceName: String
    let raceDate: String?
    let raceType: String?
    let city: String?
    let state: String?
    let raceUrl: String?
}

struct RaceResult: Codable, Identifiable {
    let id: Int
    let raceName: String
    let raceDate: String?
    let distance: String?
    let finishTimeSeconds: Int?
    let placement: Int?
    let source: String?
    let verified: Bool
}

struct OfficialResultCandidate: Codable, Identifiable {
    let provider: String
    let externalResultId: String
    let raceName: String
    let raceDate: String?
    let distance: String?
    let resultUrl: String?
    var id: String { "\(provider)-\(externalResultId)" }
}

struct SpotifySummaryTrack: Codable, Identifiable {
    let track: String
    let plays: Int
    var id: String { track }
}

struct SpotifySummaryArtist: Codable, Identifiable {
    let artist: String
    let plays: Int
    var id: String { artist }
}

struct SpotifyListeningSummary: Codable {
    let period: String
    let activitiesWithListening: Int
    let uniqueTracks: Int
    let workoutMinutes: Int
    let topTracks: [SpotifySummaryTrack]
    let topArtists: [SpotifySummaryArtist]
}

struct SpotifyPlaylistResult: Codable {
    let id: String?
    let name: String?
}

struct FriendProgress: Codable, Identifiable {
    let id: Int
    let displayName: String
    let avatarUrl: String?
    let activityCount: Int
    let durationMinutes: Int
    let distanceMeters: Int
    let days: Int
}

struct RaceListing: Decodable, Identifiable {
    let id: String
    let name: String
    let date: String?
    let city: String?
    let state: String?
    let url: String?
    let sport: String?

    enum CodingKeys: String, CodingKey { case id, name, date, city, state, url, sport, raceId, raceName, eventDate }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? c.decodeIfPresent(String.self, forKey: .raceId) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? c.decodeIfPresent(String.self, forKey: .raceName) ?? "Race"
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? c.decodeIfPresent(String.self, forKey: .eventDate)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        state = try c.decodeIfPresent(String.self, forKey: .state)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        sport = try c.decodeIfPresent(String.self, forKey: .sport)
    }
}

struct WorkoutEvent: Codable, Identifiable {
    let id: Int
    let plannedDate: String
    let title: String
    let description: String?
    let workoutType: String?
    let distanceMeters: Int?
    let durationMinutes: Int?
    let completed: Bool
}

struct StrengthVolume: Codable {
    let totalVolume: Double?
    let sessions: Int?
    let totalSets: Int?
    let totalReps: Int?
}

struct StrengthPR: Codable {
    let maxWeight: Double?
    let maxReps: Int?
    let estimatedOneRepMax: Double?
}

struct StrengthPoint: Codable, Identifiable {
    var id: String { "\(date)-\(volume ?? 0)" }
    let date: String
    let volume: Double?
}

@MainActor
final class TrainingHubService: ObservableObject {
    static let shared = TrainingHubService()
    private let api = APIClient.shared
    @Published var folders: [TrainingFolder] = []
    @Published var bookmarks: [RaceBookmark] = []
    @Published var results: [RaceResult] = []
    @Published var races: [RaceListing] = []
    @Published var events: [WorkoutEvent] = []
    @Published var exercises: [String] = []
    @Published var volume: StrengthVolume?
    @Published var prs: StrengthPR?
    @Published var history: [StrengthPoint] = []

    private init() {}

    func fetchFolders() async throws { folders = try await api.request("/training-folders") }
    func createFolder(name: String, description: String, targetDate: String?) async throws {
        struct Body: Encodable { let name: String; let description: String?; let targetDate: String? }
        let folder: TrainingFolder = try await api.request("/training-folders", method: "POST", body: Body(name: name, description: description.isEmpty ? nil : description, targetDate: targetDate))
        folders.insert(folder, at: 0)
    }
    func add(folderId: Int, type: String, itemId: Int) async throws {
        struct Body: Encodable { let itemType: String; let itemId: Int }
        let folder: TrainingFolder = try await api.request("/training-folders/\(folderId)/items", method: "POST", body: Body(itemType: type, itemId: itemId))
        if let i = folders.firstIndex(where: { $0.id == folderId }) { folders[i] = folder }
    }
    func updateFolder(id: Int, name: String, description: String, targetDate: String?) async throws {
        struct Body: Encodable { let name: String; let description: String?; let targetDate: String? }
        let folder: TrainingFolder = try await api.request("/training-folders/\(id)", method: "PATCH", body: Body(name: name, description: description, targetDate: targetDate))
        if let i = folders.firstIndex(where: { $0.id == id }) { folders[i] = folder }
    }
    func remove(folderId: Int, type: String, itemId: Int) async throws {
        try await api.requestVoid("/training-folders/\(folderId)/items/\(type)/\(itemId)", method: "DELETE")
    }

    func fetchRaces() async throws {
        struct Response: Decodable { let races: [RaceListing]? }
        let response: Response = try await api.request("/events?results_per_page=50")
        races = response.races ?? []
    }
    func fetchRaceData() async throws {
        async let b: [RaceBookmark] = api.request("/race-bookmarks")
        async let r: [RaceResult] = api.request("/race-results")
        bookmarks = try await b; results = try await r
    }
    func fetchResultProviders() async throws -> [String] { try await api.request("/race-results/providers") }
    func fetchSpotifySummary(period: String) async throws -> SpotifyListeningSummary { try await api.request("/spotify/listening-summary?period=\(period)") }
    func createSpotifyPlaylist(period: String) async throws -> SpotifyPlaylistResult {
        struct Body: Encodable { let period: String }
        return try await api.request("/spotify/playlists/from-history", method: "POST", body: Body(period: period))
    }
    func fetchFriendProgress(days: Int = 7) async throws -> [FriendProgress] { try await api.request("/friends/progress?days=\(days)") }
    func discoverResults(provider: String, raceId: String?, eventId: String?) async throws -> [OfficialResultCandidate] {
        var path = "/race-results/discover?provider=\(provider)"
        if let raceId, !raceId.isEmpty { path += "&raceId=\(raceId)" }
        if let eventId, !eventId.isEmpty { path += "&eventId=\(eventId)" }
        return try await api.request(path)
    }
    func importResult(_ candidate: OfficialResultCandidate) async throws {
        struct Body: Encodable { let source: String; let externalResultId: String; let raceName: String; let raceDate: String?; let distance: String?; let resultUrl: String?; let verified: Bool }
        let body = Body(source: candidate.provider, externalResultId: candidate.externalResultId, raceName: candidate.raceName, raceDate: candidate.raceDate, distance: candidate.distance, resultUrl: candidate.resultUrl, verified: true)
        let saved: RaceResult = try await api.request("/race-results/import", method: "POST", body: body)
        results.insert(saved, at: 0)
    }
    func bookmark(_ race: RaceListing) async throws {
        struct Body: Encodable { let externalRaceId: String; let raceName: String; let raceDate: String?; let city: String?; let state: String?; let raceUrl: String? }
        let saved: RaceBookmark = try await api.request("/race-bookmarks", method: "POST", body: Body(externalRaceId: race.id, raceName: race.name, raceDate: race.date, city: race.city, state: race.state, raceUrl: race.url))
        bookmarks.append(saved)
    }
    func removeBookmark(_ id: Int) async throws { try await api.requestVoid("/race-bookmarks/\(id)", method: "DELETE"); bookmarks.removeAll { $0.id == id } }

    func fetchCalendar(start: String, end: String) async throws { events = try await api.request("/workout-events?start=\(start)&end=\(end)") }
    func updateCalendarEvent(id: Int, completed: Bool, title: String? = nil, plannedDate: String? = nil) async throws {
        struct Body: Encodable { let completed: Bool; let title: String?; let plannedDate: String? }
        let updated: WorkoutEvent = try await api.request("/workout-events/\(id)", method: "PUT", body: Body(completed: completed, title: title, plannedDate: plannedDate))
        if let i = events.firstIndex(where: { $0.id == id }) { events[i] = updated }
    }
    func reschedule(eventId: Int, to date: String) async throws { guard let event = events.first(where: { $0.id == eventId }) else { return }; try await updateCalendarEvent(id: eventId, completed: event.completed, title: event.title, plannedDate: date) }
    func deleteCalendarEvent(id: Int) async throws { try await api.requestVoid("/workout-events/\(id)", method: "DELETE"); events.removeAll { $0.id == id } }
    func fetchStrength() async throws {
        async let e: [String] = api.request("/strength/exercises")
        async let v: StrengthVolume = api.request("/strength/volume?days=28")
        exercises = try await e; volume = try await v
        if let exercise = exercises.first { try await selectExercise(exercise) }
    }
    func selectExercise(_ exercise: String) async throws {
        let encoded = exercise.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? exercise
        async let p: StrengthPR = api.request("/strength/prs?exercise=\(encoded)")
        async let h: [StrengthPoint] = api.request("/strength/history?exercise=\(encoded)")
        prs = try await p; history = try await h
    }
}

struct IntegrationStatus: Decodable {
    let connected: Bool
    let lastSync: String?
    let needsReconnect: Bool?
}

@MainActor
final class IntegrationService: ObservableObject {
    static let shared = IntegrationService()
    private let api = APIClient.shared
    @Published var statuses: [String: IntegrationStatus] = [:]
    @Published var loading = false
    private init() {}

    func refresh() async {
        loading = true
        defer { loading = false }
        for provider in ["whoop", "oura", "fitbit", "spotify", "runsignup"] {
            if let status: IntegrationStatus = try? await api.request("/integrations/\(provider)/status") { statuses[provider] = status }
        }
    }
    func connectURL(provider: String) async throws -> URL {
        let path = provider == "spotify" ? "/spotify/connect" : provider == "runsignup" ? "/integrations/runsignup/oauth/connect" : "/integrations/\(provider)/connect"
        struct Response: Decodable { let url: String }
        let response: Response = try await api.request(path)
        guard let url = URL(string: response.url) else { throw APIError.invalidURL }
        return url
    }
    func sync(provider: String) async throws -> Int {
        struct Response: Decodable { let imported: Int? }
        let response: Response = try await api.request("/integrations/\(provider)/sync", method: "POST")
        await refresh()
        return response.imported ?? 0
    }
    func disconnect(provider: String) async throws {
        let path = provider == "runsignup" ? "/integrations/runsignup/disconnect" : provider == "spotify" ? "/integrations/spotify/disconnect" : "/integrations/\(provider)/disconnect"
        try await api.requestVoid(path, method: "DELETE")
        statuses[provider] = IntegrationStatus(connected: false, lastSync: nil, needsReconnect: false)
    }
}

struct MultisportEventSummary: Codable, Identifiable {
    let id: Int
    let name: String
    let eventType: String
    let eventDate: String?
    let segmentCount: Int
    let totalDurationSeconds: Int
    let totalDistanceMeters: Int
}

@MainActor
final class MultisportService: ObservableObject {
    static let shared = MultisportService()
    private let api = APIClient.shared
    @Published var events: [MultisportEventSummary] = []
    private init() {}
    func fetch() async throws { events = try await api.request("/multisport-events") }
    func create(name: String, type: String, date: String?, activityIds: [Int]) async throws {
        struct Segment: Encodable { let activityId: Int; let order: Int; let label: String }
        struct Body: Encodable { let name: String; let eventType: String; let eventDate: String?; let segments: [Segment] }
        let body = Body(name: name, eventType: type, eventDate: date, segments: activityIds.enumerated().map { Segment(activityId: $0.element, order: $0.offset, label: "Segment \($0.offset + 1)") })
        let _: MultisportEventSummary = try await api.request("/multisport-events", method: "POST", body: body)
        try await fetch()
    }
    func delete(id: Int) async throws { try await api.requestVoid("/multisport-events/\(id)", method: "DELETE"); events.removeAll { $0.id == id } }
}
