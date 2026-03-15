import SwiftUI

struct ActivityCard: View {
    let activity: Activity

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

            // Reaction row
            HStack(spacing: 16) {
                Label("\(activity.reactionCount ?? 0)", systemImage: "heart")
                Label("\(activity.commentCount ?? 0)", systemImage: "bubble")
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(Rectangle().stroke(Color(.systemGray5), lineWidth: 1))
    }

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
