import Foundation

// MARK: - RunnitEvent model

/// Named RunnitEvent to avoid collision with SwiftUI's internal Event type.
struct RunnitEvent: Identifiable, Decodable {
    let id: Int
    let title: String
    let sportType: String
    let eventDatetime: Date?
    let locationName: String?
    let description: String?
    let creatorId: Int
    let creatorName: String
    let attendeeCount: Int
    let myRsvpStatus: String?
    let city: String?
}

// MARK: - Create event body

struct CreateEventBody: Encodable {
    let title: String
    let sportType: String
    let eventDatetime: String   // ISO-8601 string
    let locationName: String?
    let description: String?
    let city: String?
}

// MARK: - EventService

@MainActor
final class EventService: ObservableObject {
    static let shared = EventService()

    private let api = APIClient.shared

    @Published var discoverEvents: [RunnitEvent] = []
    @Published var myEvents: [RunnitEvent] = []
    @Published var isLoading = false

    private init() {}

    // MARK: - Discover

    /// Fetches upcoming public events, optionally filtered by city.
    /// `GET /api/group-events/discover?city=CITY`
    func fetchDiscover(city: String?) async throws {
        var path = "/group-events/discover"
        if let city, !city.trimmingCharacters(in: .whitespaces).isEmpty,
           let encoded = city.trimmingCharacters(in: .whitespaces)
               .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "?city=\(encoded)"
        }
        isLoading = true
        defer { isLoading = false }
        discoverEvents = try await api.request(path)
    }

    // MARK: - My Events

    /// Fetches events the current user created or RSVPed to.
    /// `GET /api/group-events/my`
    func fetchMyEvents() async throws {
        isLoading = true
        defer { isLoading = false }
        myEvents = try await api.request("/group-events/my")
    }

    // MARK: - RSVP

    /// RSVPs to an event.
    /// `POST /api/group-events/{id}/rsvp` body: `{status: "GOING" | "INTERESTED" | "NOT_GOING"}`
    func rsvp(eventId: Int, status: String) async throws {
        struct RSVPBody: Encodable { let status: String }
        try await api.requestVoid("/group-events/\(eventId)/rsvp", method: "POST", body: RSVPBody(status: status))

        // Optimistically update the in-memory discover list so the button reflects the new status immediately
        if let idx = discoverEvents.firstIndex(where: { $0.id == eventId }) {
            let existing = discoverEvents[idx]
            discoverEvents[idx] = RunnitEvent(
                id: existing.id,
                title: existing.title,
                sportType: existing.sportType,
                eventDatetime: existing.eventDatetime,
                locationName: existing.locationName,
                description: existing.description,
                creatorId: existing.creatorId,
                creatorName: existing.creatorName,
                attendeeCount: status == "GOING" ? existing.attendeeCount + 1 : existing.attendeeCount,
                myRsvpStatus: status,
                city: existing.city
            )
        }
    }

    // MARK: - Create

    /// Creates a new group event.
    /// `POST /api/group-events`
    func createEvent(_ body: CreateEventBody) async throws -> RunnitEvent {
        let event: RunnitEvent = try await api.request("/group-events", method: "POST", body: body)
        myEvents.insert(event, at: 0)
        return event
    }
}
