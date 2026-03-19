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
    @State private var showDeleteConfirmation = false

    static let timeFormatter: DateFormatter = {
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
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .confirmationDialog("Delete \"\(preview.title)\"?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                    Button("Delete Event", role: .destructive) { onConfirm() }
                    Button("Cancel", role: .cancel) {}
                }
        case .listed:
            tappableCard
        }
    }

    // MARK: - Card variants

    private var tappableCard: some View {
        Button(action: openInCalendar) {
            cardContent(titleColor: .primary, dimmed: false)
                .overlay(alignment: .trailing) {
                    HStack(spacing: 6) {
                        if preview.hasConflict == true {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, DesignConstants.Padding.card)
                }
        }
        .buttonStyle(.plain)
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
        .padding(DesignConstants.Padding.card)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous))
        .opacity(DesignConstants.Opacity.dimmed)
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
                .padding(.trailing, DesignConstants.Padding.card)
        }
        .padding(DesignConstants.Padding.card)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous))
        .opacity(DesignConstants.Opacity.verDimmed)
    }

    // MARK: - Shared sub-views

    func cardContent(titleColor: Color, dimmed: Bool) -> some View {
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
                if let loc = preview.location {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .font(.system(size: DesignConstants.FontSize.tinyIcon))
                        Text(loc)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }
                if let cal = preview.calendarName {
                    Text(cal)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let minutes = preview.reminderMinutes {
                    HStack(spacing: 3) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: DesignConstants.FontSize.tinyIcon))
                        Text(reminderLabel(minutes))
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                if let rec = preview.recurrence {
                    HStack(spacing: 3) {
                        Image(systemName: "repeat")
                            .font(.system(size: DesignConstants.FontSize.tinyIcon))
                        Text(rec.capitalized)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(DesignConstants.Padding.card)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous))
    }

    private func dateBadge(dimmed: Bool) -> some View {
        VStack(spacing: 1) {
            Text(monthText)
                .font(.system(size: DesignConstants.FontSize.monthBadge, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .background(dimmed ? Color.gray : Color.red)
            Text(dayText)
                .font(.system(size: DesignConstants.FontSize.dayBadge, weight: .bold))
                .foregroundStyle(dimmed ? .secondary : .primary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
        }
        .frame(width: DesignConstants.Size.dateBadgeWidth)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.badge, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.badge, style: .continuous).stroke(Color(.systemGray4), lineWidth: 0.5))
    }

    // MARK: - Helpers

    static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        return f
    }()

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d"
        return f
    }()

    private var monthText: String {
        Self.monthFormatter.string(from: preview.start).uppercased()
    }

    private var dayText: String {
        Self.dayFormatter.string(from: preview.start)
    }

    private var timeText: String {
        preview.isAllDay ? "All day" : "\(Self.timeFormatter.string(from: preview.start)) – \(Self.timeFormatter.string(from: preview.end))"
    }

    func reminderLabel(_ minutes: Int) -> String {
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
