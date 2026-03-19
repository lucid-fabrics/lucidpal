import SwiftUI

// MARK: - Calendar action streaming pill

struct CalendarActionPill: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.caption)
                .opacity(pulse ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.7).repeatForever(), value: pulse)
            Text("Updating calendar…")
                .font(.caption)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, DesignConstants.Padding.cardHorizontal)
        .padding(.vertical, DesignConstants.Padding.slotRowVertical)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous))
        .onAppear { pulse = true }
    }
}
