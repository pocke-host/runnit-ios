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
    var id: String { "\(date)-\(volume)" }
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
    func bookmark(_ race: RaceListing) async throws {
        struct Body: Encodable { let externalRaceId: String; let raceName: String; let raceDate: String?; let city: String?; let state: String?; let raceUrl: String? }
        let saved: RaceBookmark = try await api.request("/race-bookmarks", method: "POST", body: Body(externalRaceId: race.id, raceName: race.name, raceDate: race.date, city: race.city, state: race.state, raceUrl: race.url))
        bookmarks.append(saved)
    }
    func removeBookmark(_ id: Int) async throws { try await api.requestVoid("/race-bookmarks/\(id)", method: "DELETE"); bookmarks.removeAll { $0.id == id } }

    func fetchCalendar(start: String, end: String) async throws { events = try await api.request("/workout-events?start=\(start)&end=\(end)") }
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
