import SwiftUI

// MARK: - Pending state card variants (deletion + update) — split from CalendarEventCard.swift

extension CalendarEventCard {

    var pendingDeletionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardContent(titleColor: .primary, dimmed: false)
            Divider().padding(.horizontal, DesignConstants.Padding.card)
            HStack(spacing: 0) {
                Button(action: onCancel) {
                    Text("Keep")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignConstants.Padding.rowVertical)
                }
                Divider().frame(height: DesignConstants.Size.dividerHeight)
                Button(action: onConfirm) {
                    Text("Delete")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignConstants.Padding.rowVertical)
                }
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous).stroke(Color.red.opacity(DesignConstants.Opacity.conflictBorder), lineWidth: 1))
    }

    var pendingUpdateCard: some View {
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
                .padding(.horizontal, DesignConstants.Padding.card)
                .padding(.bottom, DesignConstants.Padding.slotRowVertical)
            }
            Divider().padding(.horizontal, DesignConstants.Padding.card)
            HStack(spacing: 0) {
                Button(action: onCancelUpdate) {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignConstants.Padding.rowVertical)
                }
                Divider().frame(height: DesignConstants.Size.dividerHeight)
                Button(action: onConfirmUpdate) {
                    Text("Apply")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignConstants.Padding.rowVertical)
                }
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous).stroke(Color.accentColor.opacity(DesignConstants.Opacity.updateBorder), lineWidth: 1))
    }

    @ViewBuilder func diffRow(label: String, from current: String, to proposed: String) -> some View {
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
                    .font(.system(size: DesignConstants.FontSize.microIcon))
                    .foregroundStyle(.secondary)
            }
            Text(proposed)
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
        }
    }
}
