import SwiftUI

struct ActivityCard: View {
    let activity: Activity
    // Reactions are handled at the detail level — card just shows counts + quick-react
    @State private var localReactionCount: Int
    @State private var localUserReaction: String?
    @State private var isReacting = false

    init(activity: Activity) {
        self.activity = activity
        _localReactionCount = State(initialValue: activity.reactionCount ?? 0)
        _localUserReaction = State(initialValue: activity.userReaction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: avatar + name + date
            HStack(spacing: 10) {
                AsyncImage(url: URL(string: activity.userAvatarUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray5))
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.userDisplayName ?? "Athlete")
                        .font(.system(size: 14, weight: .semibold))
                    if let date = activity.date {
                        Text(date.formatted(.relative(presentation: .named)))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: activity.activityIcon)
                    .foregroundStyle(.secondary)
            }

            // Title
            if let title = activity.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }

            // Stats row
            HStack(spacing: 20) {
                if let d = activity.distanceMeters {
                    StatPill(label: "DIST", value: String(format: "%.2f km", d / 1000))
                }
                if let dur = activity.durationSeconds {
                    StatPill(label: "TIME", value: formatDuration(dur))
                }
                if let pace = activity.paceSecondsPerKm {
                    StatPill(label: "PACE", value: formatPace(pace))
                }
            }

            // Reactions + comment count
            HStack(spacing: 4) {
                ReactionButton(emoji: "❤️", type: "LIKE",  current: localUserReaction, isReacting: isReacting, action: react)
                ReactionButton(emoji: "🔥", type: "FIRE",  current: localUserReaction, isReacting: isReacting, action: react)
                ReactionButton(emoji: "👏", type: "CLAP",  current: localUserReaction, isReacting: isReacting, action: react)

                if localReactionCount > 0 {
                    Text("\(localReactionCount)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }

                Spacer()

                Label("\(activity.commentCount ?? 0)", systemImage: "bubble")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(Rectangle().stroke(Color(.systemGray5), lineWidth: 1))
    }

    // MARK: - Reaction

    private func react(type: String) {
        guard !isReacting else { return }
        isReacting = true

        let wasReaction = localUserReaction
        if localUserReaction == type {
            // Toggle off
            localUserReaction = nil
            localReactionCount = max(0, localReactionCount - 1)
        } else {
            // Switch or add
            if localUserReaction == nil { localReactionCount += 1 }
            localUserReaction = type
        }

        Task {
            do {
                if wasReaction == type {
                    try await ActivityService.shared.removeReaction(activityId: activity.id)
                } else {
                    try await ActivityService.shared.addReaction(activityId: activity.id, type: type)
                }
            } catch {
                // Revert optimistic update
                localUserReaction = wasReaction
                localReactionCount = activity.reactionCount ?? 0
            }
            isReacting = false
        }
    }

    // MARK: - Formatting

    private func formatDuration(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private func formatPace(_ secPerKm: Double) -> String {
        let min = Int(secPerKm) / 60
        let sec = Int(secPerKm) % 60
        return String(format: "%d:%02d /km", min, sec)
    }
}

// MARK: - ReactionButton

struct ReactionButton: View {
    let emoji: String
    let type: String
    let current: String?
    let isReacting: Bool
    let action: (String) -> Void

    var isActive: Bool { current == type }

    var body: some View {
        Button {
            action(type)
        } label: {
            Text(emoji)
                .font(.system(size: 18))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(isActive ? Color(.systemGray5) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(isReacting)
    }
}

// MARK: - StatPill

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
        }
    }
}
