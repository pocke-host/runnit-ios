import SwiftUI

struct TrainingFoldersView: View {
    @StateObject private var service = TrainingHubService.shared
    @State private var showingCreate = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Training folders")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingCreate = true } label: { Image(systemName: "plus") } } }
                .background(RunnitTheme.canvas)
                .task { do { try await service.fetchFolders() } catch let requestError { error = requestError.localizedDescription } }
                .sheet(isPresented: $showingCreate) { CreateFolderSheet(service: service) }
                .alert("Folders", isPresented: .init(get: { error != nil }, set: { _ in error = nil })) { Button("OK", role: .cancel) {} } message: { Text(error ?? "") }
        }
    }

    @ViewBuilder private var content: some View {
        if service.folders.isEmpty {
            ContentUnavailableView("Build your training block", systemImage: "folder.badge.plus", description: Text("Create a folder for a race, season, or goal."))
        } else {
            List(service.folders) { folder in
                NavigationLink(destination: TrainingFolderDetailView(folder: folder)) {
                    FolderRow(folder: folder)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct FolderRow: View {
    let folder: TrainingFolder
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(folder.name).font(.headline); Spacer(); Text("\(folder.items.count) items").font(.caption).foregroundStyle(RunnitTheme.muted) }
            Text(folder.description ?? "A focused training block.").font(.subheadline).foregroundStyle(RunnitTheme.muted)
            if let date = folder.targetDate { Label("Target \(date)", systemImage: "flag").font(.caption).foregroundStyle(RunnitTheme.signal) }
        }.padding(.vertical, 8)
    }
}

private struct CreateFolderSheet: View {
    @ObservedObject var service: TrainingHubService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var target = Date()
    var body: some View {
        NavigationStack {
            Form {
                Section("TRAINING BLOCK") {
                    TextField("London Marathon", text: $name)
                    TextField("Spring build", text: $description)
                    DatePicker("Target date", selection: $target, displayedComponents: .date)
                }
            }
            .navigationTitle("New folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
                            try? await service.createFolder(name: name, description: description, targetDate: formatter.string(from: target))
                            dismiss()
                        }
                    }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct TrainingFolderDetailView: View {
    let folder: TrainingFolder
    @StateObject private var service = TrainingHubService.shared
    @State private var activities: [Activity] = []
    @State private var error: String?
    var body: some View {
        List {
            Section { FolderSummary(folder: folder) }
            Section("ATTACHED WORKOUTS") {
                if folder.items.isEmpty { Text("No workouts attached yet.").foregroundStyle(RunnitTheme.muted) }
                else { ForEach(folder.items) { item in Label("\(item.itemType.capitalized) #\(item.itemId)", systemImage: item.itemType == "ACTIVITY" ? "figure.run" : "calendar") } }
            }
            Section("RECENT ACTIVITIES") {
                ForEach(activities) { activity in
                    Button { Task { try? await service.add(folderId: folder.id, type: "ACTIVITY", itemId: activity.id) } } label: {
                        HStack { Image(systemName: activity.activityIcon); Text(activity.title ?? activity.activityType.capitalized); Spacer(); Text(activity.formattedDistance).font(.caption).foregroundStyle(RunnitTheme.muted) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(RunnitTheme.canvas)
        .navigationTitle("Folder").navigationBarTitleDisplayMode(.inline)
        .task { do { try await ActivityService.shared.fetchMyActivities(); activities = ActivityService.shared.myActivities } catch let requestError { error = requestError.localizedDescription } }
        .alert("Folder", isPresented: .init(get: { error != nil }, set: { _ in error = nil })) { Button("OK", role: .cancel) {} } message: { Text(error ?? "") }
    }
}

private struct FolderSummary: View {
    let folder: TrainingFolder
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(folder.name).font(.title.bold())
            Text(folder.description ?? "Focused training block").foregroundStyle(RunnitTheme.muted)
            ProgressView(value: Double(folder.items.count), total: 20).tint(RunnitTheme.signal)
            Text("\(folder.items.count) tracked items · keep building momentum").font(.caption).foregroundStyle(RunnitTheme.muted)
        }.padding(.vertical, 10)
    }
}
