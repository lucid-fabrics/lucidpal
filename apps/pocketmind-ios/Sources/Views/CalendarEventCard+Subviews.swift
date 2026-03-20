import SwiftUI

// MARK: - Card variant subviews

extension CalendarEventCard {

    var deletedCard: some View {
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

    var staleCard: some View {
        HStack(spacing: 10) {
            dateBadge(dimmed: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(preview.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(timeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Removed from calendar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(DesignConstants.Padding.card)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous))
        .opacity(DesignConstants.Opacity.verDimmed)
    }

    var conflictBanner: some View {
        Button { showConflictSheet = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                let n = preview.conflictingEvents.count
                Text("Conflicts with \(n) event\(n == 1 ? "" : "s") — tap to review")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange.opacity(0.6))
            }
            .padding(.horizontal, DesignConstants.Padding.card)
            .padding(.vertical, 7)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    func statusCard(icon: String, label: String, color: Color) -> some View {
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
}
