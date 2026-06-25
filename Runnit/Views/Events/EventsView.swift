import SwiftUI

// MARK: - EventsView

struct EventsView: View {
    @StateObject private var eventService = EventService.shared
    @EnvironmentObject var auth: AuthService

    @State private var selectedSegment = 0   // 0 = Discover, 1 = My Events
    @State private var cityFilter = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Events", selection: $selectedSegment) {
                    Text("Discover").tag(0)
                    Text("My Events").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                if selectedSegment == 0 {
                    DiscoverEventsSection(
                        eventService: eventService,
                        cityFilter: $cityFilter,
                        errorMessage: $errorMessage
                    )
                } else {
                    MyEventsSection(
                        eventService: eventService,
                        errorMessage: $errorMessage
                    )
                }
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

// MARK: - Discover Events Section

private struct DiscoverEventsSection: View {
    @ObservedObject var eventService: EventService
    @Binding var cityFilter: String
    @Binding var errorMessage: String?

    @State private var searchTask: Task<Void, Never>?

    var sortedEvents: [RunnitEvent] {
        eventService.discoverEvents.sorted {
            guard let a = $0.eventDatetime, let b = $1.eventDatetime else { return false }
            return a < b
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // City filter bar
            HStack(spacing: 10) {
                Image(systemName: "mappin")
                    .foregroundStyle(.secondary)
                TextField("Filter by city...", text: $cityFilter)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .onChange(of: cityFilter) { _, new in debounce(city: new) }
                if !cityFilter.isEmpty {
                    Button { cityFilter = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            Group {
                if eventService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sortedEvents.isEmpty {
                    ContentUnavailableView(
                        "No Upcoming Events",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Check back soon or try a different city.")
                    )
                } else {
                    List(sortedEvents) { event in
                        EventRow(event: event, errorMessage: $errorMessage)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
        }
        .task {
            do {
                try await eventService.fetchDiscover(city: cityFilter.isEmpty ? nil : cityFilter)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func debounce(city: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            do {
                try await eventService.fetchDiscover(city: city.isEmpty ? nil : city)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - My Events Section

private struct MyEventsSection: View {
    @ObservedObject var eventService: EventService
    @Binding var errorMessage: String?

    var sortedEvents: [RunnitEvent] {
        eventService.myEvents.sorted {
            guard let a = $0.eventDatetime, let b = $1.eventDatetime else { return false }
            return a < b
        }
    }

    var body: some View {
        Group {
            if eventService.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sortedEvents.isEmpty {
                ContentUnavailableView(
                    "No Events Yet",
                    systemImage: "calendar.badge.plus",
                    description: Text("Events you create or RSVP to will appear here.")
                )
            } else {
                List(sortedEvents) { event in
                    EventRow(event: event, errorMessage: $errorMessage)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .task {
            do {
                try await eventService.fetchMyEvents()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - EventRow

struct EventRow: View {
    let event: RunnitEvent
    @Binding var errorMessage: String?

    @State private var rsvpStatus: String?
    @State private var isRSVPing = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    init(event: RunnitEvent, errorMessage: Binding<String?>) {
        self.event = event
        self._errorMessage = errorMessage
        _rsvpStatus = State(initialValue: event.myRsvpStatus)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .bold))

                    if let date = event.eventDatetime {
                        Label(Self.dateFormatter.string(from: date), systemImage: "clock")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    if let location = event.locationName {
                        Label(location, systemImage: "mappin")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Sport badge
                Text(event.sportType)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            HStack {
                Label("\(event.attendeeCount) going", systemImage: "person.2")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text("by \(event.creatorName)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                // RSVP menu
                RSVPButton(
                    currentStatus: rsvpStatus,
                    isLoading: isRSVPing
                ) { status in
                    sendRSVP(status)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sendRSVP(_ status: String) {
        let previous = rsvpStatus
        rsvpStatus = status // optimistic
        isRSVPing = true
        Task {
            do {
                try await EventService.shared.rsvp(eventId: event.id, status: status)
            } catch {
                rsvpStatus = previous // revert
                errorMessage = error.localizedDescription
            }
            isRSVPing = false
        }
    }
}

// MARK: - RSVPButton

private struct RSVPButton: View {
    let currentStatus: String?
    let isLoading: Bool
    let onSelect: (String) -> Void

    private var label: String {
        switch currentStatus {
        case "GOING":        return "Going"
        case "INTERESTED":   return "Interested"
        case "NOT_GOING":    return "Not Going"
        default:             return "RSVP"
        }
    }

    private var icon: String {
        switch currentStatus {
        case "GOING":        return "checkmark.circle.fill"
        case "INTERESTED":   return "star.fill"
        case "NOT_GOING":    return "xmark.circle"
        default:             return "calendar.badge.plus"
        }
    }

    var body: some View {
        if isLoading {
            ProgressView()
                .frame(width: 80, height: 30)
        } else {
            Menu {
                Button {
                    onSelect("GOING")
                } label: {
                    Label("Going", systemImage: "checkmark.circle.fill")
                }
                Button {
                    onSelect("INTERESTED")
                } label: {
                    Label("Interested", systemImage: "star.fill")
                }
                Button {
                    onSelect("NOT_GOING")
                } label: {
                    Label("Not Going", systemImage: "xmark.circle")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(currentStatus == "GOING" ? Color.black : Color(.systemGray5))
                .foregroundStyle(currentStatus == "GOING" ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
