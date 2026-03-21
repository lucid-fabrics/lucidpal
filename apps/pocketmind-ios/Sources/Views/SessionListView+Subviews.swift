import SwiftUI

// MARK: - Next Event Card

struct NextEventCard: View {
    let event: CalendarEventInfo
    let title: String
    let now: Date
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text(timeUntil)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(event.startDate, style: .time)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var timeUntil: String {
        let mins = Int(event.startDate.timeIntervalSince(now) / 60)
        if mins < 1  { return "Starting now" }
        if mins < 60 { return "in \(mins) min" }
        let h = mins / 60, m = mins % 60
        return m == 0 ? "in \(h)h" : "in \(h)h \(m)m"
    }
}

// MARK: - Pulsing Mic Button

struct PulsingMicButton: View {
    let action: () -> Void
    @State private var pulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulse ring
                Circle()
                    .stroke(Color.accentColor.opacity(pulsing ? 0 : 0.3), lineWidth: 2)
                    .frame(width: pulsing ? 108 : 88, height: pulsing ? 108 : 88)
                    .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulsing)

                // Main button
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 16, y: 6)

                Image(systemName: "mic.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .onAppear { pulsing = true }
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    let meta: ChatSessionMeta
    var searchText: String = ""

    private var highlightedTitle: AttributedString {
        var attributed = AttributedString(meta.title)
        guard !searchText.isEmpty,
              let range = attributed.range(of: searchText, options: .caseInsensitive) else {
            return attributed
        }
        attributed[range].foregroundColor = .accentColor
        attributed[range].font = .body.bold()
        return attributed
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(highlightedTitle)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(smartTimestamp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let preview = meta.lastMessagePreview, !preview.isEmpty {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("No messages yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 42, height: 42)
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.accentColor)
        }
    }

    private var smartTimestamp: String {
        let cal = Calendar.current
        let date = meta.updatedAt
        if cal.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if cal.isDateInYesterday(date) {
            return "Yesterday"
        } else if let weekAgo = cal.date(byAdding: .day, value: -7, to: .now), date >= weekAgo {
            return date.formatted(.dateTime.weekday(.wide))
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}
