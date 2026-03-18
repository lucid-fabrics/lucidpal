import AppIntents

/// Registers suggested Siri phrases for PocketMind.
/// Requires iOS 16.4+; on older builds the intent still works but phrases
/// must be added manually via the Shortcuts app.
@available(iOS 16.4, *)
struct PocketMindShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskPocketMindIntent(),
            // String parameters are not supported in AppShortcut phrases (only AppEntity/AppEnum).
            // Siri will prompt "What would you like to ask?" via requestValueDialog after activation.
            phrases: [
                "Ask \(.applicationName)",
                "Open \(.applicationName) and ask a question",
                "Ask my \(.applicationName) assistant"
            ],
            shortTitle: "Ask PocketMind",
            systemImageName: "brain"
        )
    }
}
