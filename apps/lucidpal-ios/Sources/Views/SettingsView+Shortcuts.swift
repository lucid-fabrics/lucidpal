import SwiftUI

extension SettingsView {

    var shortcutsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("LucidPal actions are available in the Shortcuts app for automation.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    shortcutRow(icon: "brain.head.profile", title: "Ask LucidPal", description: "Query AI assistant and get text response")
                    shortcutRow(icon: "calendar.badge.plus", title: "Create Event", description: "Add calendar event with title, time, duration")
                    shortcutRow(icon: "calendar.badge.clock", title: "Check Next Meeting", description: "Get details of upcoming calendar event")
                    shortcutRow(icon: "clock.badge.checkmark", title: "Find Free Time", description: "Search for available time slots")
                }
            }
            .padding(.vertical, 4)

            if let shortcutsURL = URL(string: "shortcuts://") {
                Link(destination: shortcutsURL) {
                    HStack {
                        Label("Open Shortcuts App", systemImage: "arrow.up.forward.app")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            sectionHeader("Shortcuts", icon: "rectangle.connected.to.line.below", color: .green)
        }
    }

    @ViewBuilder
    func shortcutRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
