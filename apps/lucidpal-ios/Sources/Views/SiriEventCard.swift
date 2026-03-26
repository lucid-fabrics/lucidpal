import SwiftUI

// MARK: - Siri snippet view

struct SiriEventCard: View {
    let title: String
    let start: Date
    let end: Date
    let calendarName: String?
    let isAllDay: Bool
    let deleted: Bool

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        return f
    }()
    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d"
        return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text(Self.monthFmt.string(from: start).uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(deleted ? Color.gray : Color.red)
                Text(Self.dayFmt.string(from: start))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(deleted ? .secondary : .primary)
                    .padding(.bottom, 4)
            }
            .frame(width: 44)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(deleted ? .secondary : .primary)
                    .strikethrough(deleted, color: .secondary)
                    .lineLimit(1)
                Text(isAllDay ? "All day" : "\(Self.timeFmt.string(from: start)) – \(Self.timeFmt.string(from: end))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let cal = calendarName {
                    Text(cal)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if deleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(deleted ? 0.7 : 1)
    }
}
