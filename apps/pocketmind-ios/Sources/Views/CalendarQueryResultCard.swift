import SwiftUI

// MARK: - Calendar query result card

struct CalendarQueryResultCard: View {
    let slots: [CalendarFreeSlot]
    @Environment(\.openURL) private var openURL

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Available Slots")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(slots.count) found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignConstants.Padding.cardHorizontal)
            .padding(.vertical, DesignConstants.Padding.rowVertical)

            Divider().padding(.horizontal, DesignConstants.Padding.card)

            if slots.isEmpty {
                Text("No free slots found in that range.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    // swiftlint:disable:next multiple_closures_with_trailing_closure
                    Button(action: { openInCalendar(slot) }) {
                        HStack(spacing: 12) {
                            // Date badge
                            VStack(spacing: 1) {
                                Text(Self.dateFormatter.string(from: slot.start).components(separatedBy: ",").first ?? "")
                                    .font(.system(size: DesignConstants.FontSize.monthBadge, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor)
                                Text(dayNumber(slot.start))
                                    .font(.system(size: DesignConstants.FontSize.slotDayBadge, weight: .bold))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom, 3)
                            }
                            .frame(width: DesignConstants.Size.slotBadgeWidth)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.compactBadge, style: .continuous))
                            // swiftlint:disable:next line_length
                            .overlay(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.compactBadge, style: .continuous).stroke(Color(.systemGray4), lineWidth: 0.5))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(Self.dateFormatter.string(from: slot.start))
                                    .font(.subheadline.weight(.medium))
                                Text("\(Self.timeFormatter.string(from: slot.start)) – \(Self.timeFormatter.string(from: slot.end))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, DesignConstants.Padding.cardHorizontal)
                        .padding(.vertical, DesignConstants.Padding.slotRowVertical)
                    }
                    .buttonStyle(.plain)

                    if index < slots.count - 1 {
                        Divider().padding(.horizontal, DesignConstants.Padding.card)
                    }
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous))
        // swiftlint:disable:next line_length
        .overlay(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous).stroke(Color.accentColor.opacity(DesignConstants.Opacity.slotBorder), lineWidth: 1))
    }

    private func dayNumber(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func openInCalendar(_ slot: CalendarFreeSlot) {
        let interval = slot.start.timeIntervalSinceReferenceDate
        guard let url = URL(string: "calshow:\(Int(interval))") else { return }
        openURL(url)
    }
}
