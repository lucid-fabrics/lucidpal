import SwiftUI

extension SettingsView {

    var shortcutsSection: some View {
        Section("Shortcuts Integration") {
            VStack(alignment: .leading, spacing: 8) {
                Text("PocketMind actions are available in the Shortcuts app for automation.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    shortcutRow(icon: "brain.head.profile", title: "Ask PocketMind", description: "Query AI assistant and get text response")
                    shortcutRow(icon: "calendar.badge.plus", title: "Create Event", description: "Add calendar event with title, time, duration")
                    shortcutRow(icon: "calendar.badge.clock", title: "Check Next Meeting", description: "Get details of upcoming calendar event")
                    shortcutRow(icon: "clock.badge.checkmark", title: "Find Free Time", description: "Search for available time slots")
                }
            }
            .padding(.vertical, 4)

            if let shortcutsURL = URL(string: "shortcuts://") {
                Link(destination: shortcutsURL) {
                    HStack {
                        Label("Open Shortcuts App", systemImage: "link")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func shortcutRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
