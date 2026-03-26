import AppIntents

/// Registers suggested Siri phrases for LucidPal.
/// Requires iOS 16.4+; on older builds the intents still work but phrases
/// must be added manually via the Shortcuts app.
@available(iOS 16.4, *)
struct LucidPalShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Ask LucidPal a free-form question
        AppShortcut(
            intent: AskLucidPalIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Ask \(.applicationName) a question",
                "Open \(.applicationName) and ask a question",
                "Ask my \(.applicationName) assistant"
            ],
            shortTitle: "Ask LucidPal",
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

        // Delete a calendar event with confirmation
        AppShortcut(
            intent: DeleteCalendarEventIntent(),
            phrases: [
                "Delete event in \(.applicationName)",
                "Delete a \(.applicationName) event",
                "Remove event from \(.applicationName)"
            ],
            shortTitle: "Delete Event",
            systemImageName: "calendar.badge.minus"
        )

        // Undo the last calendar action (deletion, creation, update)
        AppShortcut(
            intent: UndoLastDeletionIntent(),
            phrases: [
                "Undo my last \(.applicationName) action",
                "Undo what I just did in \(.applicationName)",
                "Undo last \(.applicationName) change",
                "Undo last deletion in \(.applicationName)",
                "Restore deleted event in \(.applicationName)",
                "Undo \(.applicationName) deletion"
            ],
            shortTitle: "Undo Last Action",
            systemImageName: "arrow.uturn.backward.circle"
        )

        // Shortcuts-compatible: Create event (background, returns value)
        AppShortcut(
            intent: CreateEventShortcutIntent(),
            phrases: [
                "Create event in Shortcuts with \(.applicationName)",
                "Make calendar event with \(.applicationName)",
                "Schedule event via \(.applicationName)"
            ],
            shortTitle: "Create Event (Shortcuts)",
            systemImageName: "calendar.badge.plus"
        )

        // Shortcuts-compatible: Check next meeting (background, returns value)
        AppShortcut(
            intent: CheckNextMeetingIntent(),
            phrases: [
                "When is my next meeting in \(.applicationName)",
                "What's my next event in \(.applicationName)",
                "Next appointment in \(.applicationName)"
            ],
            shortTitle: "Next Meeting",
            systemImageName: "calendar.badge.clock"
        )

        // Shortcuts-compatible: Find free time (background, returns value)
        AppShortcut(
            intent: FindFreeTimeShortcutIntent(),
            phrases: [
                "Find available time with \(.applicationName)",
                "Check free slots in \(.applicationName)",
                "When am I available in \(.applicationName)"
            ],
            shortTitle: "Find Free Time (Shortcuts)",
            systemImageName: "clock.badge.checkmark"
        )

        // Shortcuts-compatible: Ask LucidPal (background, opens app)
        AppShortcut(
            intent: AskLucidPalShortcutIntent(),
            phrases: [
                "Quick ask \(.applicationName)",
                "Fast question for \(.applicationName)"
            ],
            shortTitle: "Quick Ask",
            systemImageName: "brain.head.profile"
        )
    }
}
