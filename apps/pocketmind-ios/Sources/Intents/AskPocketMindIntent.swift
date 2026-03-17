import AppIntents

/// Siri intent — user says "Ask PocketMind [query]".
/// The query is stored in UserDefaults; PocketMindApp picks it up
/// when the scene becomes active and forwards it to ChatViewModel.
struct AskPocketMindIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask PocketMind"
    static var description = IntentDescription("Ask your on-device AI assistant a question")

    // iOS opens the app after perform() returns.
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Question",
               description: "What would you like to ask PocketMind?",
               requestValueDialog: IntentDialog("What would you like to ask?"))
    var query: String

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(query, forKey: "pm_siri_pending_query")
        return .result()
    }
}
