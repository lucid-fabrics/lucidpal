import SwiftUI

// MARK: - Grouped calendar event list card (read-only list results)

struct CalendarEventListCard: View {
    let events: [CalendarEventPreview]
    @Environment(\.openURL) private var openURL

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private var headerLabel: String {
        guard let first = events.first else { return "\(events.count) events" }
        let cal = Calendar.current
        let count = events.count
        let noun = count == 1 ? "event" : "events"

        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"

        // Multi-day span: show date range
        if let last = events.last,
           !cal.isDate(first.start, inSameDayAs: last.start) {
            return "\(f.string(from: first.start)) – \(f.string(from: last.start)) · \(count) \(noun)"
        }

        // Single day
        if cal.isDateInToday(first.start) { return "Today · \(count) \(noun)" }
        if cal.isDateInTomorrow(first.start) { return "Tomorrow · \(count) \(noun)" }
        return "\(f.string(from: first.start)) · \(count) \(noun)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            eventRows
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(.systemGray4), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text(headerLabel)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { openFirstInCalendar() }
    }

    // MARK: - Event rows

    @ViewBuilder
    private var eventRows: some View {
        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
            // swiftlint:disable:next multiple_closures_with_trailing_closure
            Button(action: { openInCalendar(event) }) {
                eventRow(event)
            }
            .buttonStyle(CalendarCardPressStyle())

            if index < events.count - 1 {
                Divider().padding(.leading, 34)
            }
        }
    }

    @ViewBuilder
    private func eventRow(_ event: CalendarEventPreview) -> some View {
        HStack(spacing: 12) {
            // Colored left accent bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor(for: event))
                .frame(width: 4, height: 38)
                .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(timeText(event))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let calName = event.calendarName {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(calName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let location = event.location {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Image(systemName: "mappin")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.trailing, 14)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func timeText(_ event: CalendarEventPreview) -> String {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(event.start)
        if event.isAllDay {
            return isToday ? "All day" : "\(datePrefix(event.start)) · All day"
        }
        let start = Self.timeFormatter.string(from: event.start)
        let end = Self.timeFormatter.string(from: event.end)
        let times = "\(start) – \(end)"
        return isToday ? times : "\(datePrefix(event.start)) · \(times)"
    }

    private func datePrefix(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    /// Cycles through a small palette so consecutive events feel distinct.
    private func accentColor(for event: CalendarEventPreview) -> Color {
        let palette: [Color] = [.accentColor, .purple, .orange, .green, .pink, .teal]
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else {
            return .accentColor
        }
        return palette[idx % palette.count]
    }

    private func openInCalendar(_ event: CalendarEventPreview) {
        let interval = event.start.timeIntervalSinceReferenceDate
        guard let url = URL(string: "calshow:\(Int(interval))") else { return }
        openURL(url)
    }

    private func openFirstInCalendar() {
        guard let first = events.first else { return }
        openInCalendar(first)
    }
}
