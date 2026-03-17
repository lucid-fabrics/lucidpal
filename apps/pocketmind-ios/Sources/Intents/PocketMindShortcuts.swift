import AppIntents

/// Registers suggested Siri phrases for PocketMind.
/// Requires iOS 16.4+; on older builds the intent still works but phrases
/// must be added manually via the Shortcuts app.
@available(iOS 16.4, *)
struct PocketMindShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskPocketMindIntent(),
            phrases: [
                "Ask \(.applicationName) \(\.$query)",
                "Ask \(.applicationName) to \(\.$query)",
                "Tell \(.applicationName) \(\.$query)"
            ],
            shortTitle: "Ask PocketMind",
            systemImageName: "brain"
        )
    }
}
