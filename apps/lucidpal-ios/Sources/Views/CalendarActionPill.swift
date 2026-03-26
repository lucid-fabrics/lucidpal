import SwiftUI

// MARK: - Web search result pill (static)

struct WebSearchPill: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.caption)
            Text("Web search")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, DesignConstants.Padding.cardHorizontal)
        .padding(.vertical, DesignConstants.Padding.slotRowVertical)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }
}

// MARK: - Web searching pill (animated, shown while search is in flight)

struct WebSearchingPill: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.caption)
                .opacity(pulse ? 0.3 : 1.0)
                .animation(reduceMotion ? .default : .easeInOut(duration: 0.7).repeatForever(), value: pulse)
            Text("Searching the web…")
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

// MARK: - Calendar action streaming pill

struct CalendarActionPill: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.caption)
                .opacity(pulse ? 0.3 : 1.0)
                .animation(reduceMotion ? .default : .easeInOut(duration: 0.7).repeatForever(), value: pulse)
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
