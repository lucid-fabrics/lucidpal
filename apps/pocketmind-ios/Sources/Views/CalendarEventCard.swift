import SwiftUI

// MARK: - Calendar event card

struct CalendarEventCard: View {
    let preview: CalendarEventPreview
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onUndo: () -> Void
    let onConfirmUpdate: () -> Void
    let onCancelUpdate: () -> Void

    @Environment(\.openURL) private var openURL

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        switch preview.state {
        case .pendingDeletion:
            pendingDeletionCard
        case .deleted:
            deletedCard
        case .deletionCancelled:
            statusCard(icon: "xmark.circle", label: "Deletion cancelled", color: .secondary)
        case .pendingUpdate:
            pendingUpdateCard
        case .updateCancelled:
            statusCard(icon: "xmark.circle", label: "Update cancelled", color: .secondary)
        case .created, .updated, .rescheduled, .restored:
            tappableCard
        }
    }

    // MARK: - Card variants

    private var tappableCard: some View {
        Button(action: openInCalendar) {
            cardContent(titleColor: .primary, dimmed: false)
                .overlay(alignment: .trailing) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 10)
                }
        }
        .buttonStyle(.plain)
    }

    private var pendingDeletionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardContent(titleColor: .primary, dimmed: false)
            Divider().padding(.horizontal, 10)
            HStack(spacing: 0) {
                Button(action: onCancel) {
                    Text("Keep")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                Divider().frame(height: 36)
                Button(action: onConfirm) {
                    Text("Delete")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.red.opacity(0.3), lineWidth: 1))
    }

    private var pendingUpdateCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardContent(titleColor: .primary, dimmed: false)
            if let p = preview.pendingUpdate {
                VStack(alignment: .leading, spacing: 3) {
                    if let t = p.title { diffRow(label: "Title", from: preview.title, to: t) }
                    if let s = p.start { diffRow(label: "Start", from: Self.timeFormatter.string(from: preview.start), to: Self.timeFormatter.string(from: s)) }
                    if let e = p.end   { diffRow(label: "End",   from: Self.timeFormatter.string(from: preview.end),   to: Self.timeFormatter.string(from: e)) }
                    if let l = p.location { diffRow(label: "Location", from: "", to: l) }
                    if let m = p.reminderMinutes { diffRow(label: "Reminder", from: "", to: reminderLabel(m)) }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            Divider().padding(.horizontal, 10)
            HStack(spacing: 0) {
                Button(action: onCancelUpdate) {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                Divider().frame(height: 36)
                Button(action: onConfirmUpdate) {
                    Text("Apply")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
    }

    @ViewBuilder
    private func diffRow(label: String, from current: String, to proposed: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if !current.isEmpty && current != proposed {
                Text(current)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .strikethrough(true, color: .secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
            }
            Text(proposed)
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
        }
    }

    private var deletedCard: some View {
        HStack(spacing: 10) {
            dateBadge(dimmed: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(preview.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .strikethrough(true, color: .secondary)
                    .lineLimit(1)
                Text(timeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onUndo) {
                Text("Undo")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(0.85)
    }

    private func statusCard(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            dateBadge(dimmed: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(preview.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .strikethrough(preview.state == .deleted, color: .secondary)
                    .lineLimit(1)
                Text(timeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .padding(.trailing, 10)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(0.6)
    }

    // MARK: - Shared sub-views

    private func cardContent(titleColor: Color, dimmed: Bool) -> some View {
        HStack(spacing: 12) {
            dateBadge(dimmed: dimmed)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(preview.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                    if preview.state == .rescheduled {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(timeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let cal = preview.calendarName {
                    Text(cal)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let minutes = preview.reminderMinutes {
                    HStack(spacing: 3) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 8))
                        Text(reminderLabel(minutes))
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                if let rec = preview.recurrence {
                    HStack(spacing: 3) {
                        Image(systemName: "repeat")
                            .font(.system(size: 8))
                        Text(rec.capitalized)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func dateBadge(dimmed: Bool) -> some View {
        VStack(spacing: 1) {
            Text(monthText)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .background(dimmed ? Color.gray : Color.red)
            Text(dayText)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(dimmed ? .secondary : .primary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
        }
        .frame(width: 44)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color(.systemGray4), lineWidth: 0.5))
    }

    // MARK: - Helpers

    private var monthText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        return f.string(from: preview.start).uppercased()
    }

    private var dayText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d"
        return f.string(from: preview.start)
    }

    private var timeText: String {
        preview.isAllDay ? "All day" : "\(Self.timeFormatter.string(from: preview.start)) – \(Self.timeFormatter.string(from: preview.end))"
    }

    private func reminderLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m before" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h before" : "\(h)h \(m)m before"
    }

    private func openInCalendar() {
        // calshow:<NSTimeInterval> opens Calendar scrolled to the event's date/time.
        let interval = preview.start.timeIntervalSinceReferenceDate
        guard let url = URL(string: "calshow:\(Int(interval))") ?? URL(string: "calshow://") else { return }
        openURL(url)
    }
}
