import AppIntents

/// Registers suggested Siri phrases for PocketMind.
/// Requires iOS 16.4+; on older builds the intents still work but phrases
/// must be added manually via the Shortcuts app.
@available(iOS 16.4, *)
struct PocketMindShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Ask PocketMind a free-form question
        AppShortcut(
            intent: AskPocketMindIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Ask \(.applicationName) a question",
                "Open \(.applicationName) and ask a question",
                "Ask my \(.applicationName) assistant"
            ],
            shortTitle: "Ask PocketMind",
            systemImageName: "brain"
        )

        // Check calendar — no follow-up prompt needed
        AppShortcut(
            intent: CheckCalendarIntent(),
            phrases: [
                "Check my \(.applicationName) calendar",
                "What's on my \(.applicationName) calendar",
                "Show my \(.applicationName) schedule",
                "Open my \(.applicationName) schedule"
            ],
            shortTitle: "Check Calendar",
            systemImageName: "calendar"
        )

        // Add a calendar event
        AppShortcut(
            intent: AddCalendarEventIntent(),
            phrases: [
                "Add event to \(.applicationName)",
                "Add to my \(.applicationName) calendar",
                "Create event in \(.applicationName)"
            ],
            shortTitle: "Add Event",
            systemImageName: "calendar.badge.plus"
        )

        // Find a free time slot
        AppShortcut(
            intent: FindFreeTimeIntent(),
            phrases: [
                "Find free time in \(.applicationName)",
                "Find a free slot in \(.applicationName)",
                "When am I free in \(.applicationName)"
            ],
            shortTitle: "Find Free Time",
            systemImageName: "clock"
        )
    }
}
