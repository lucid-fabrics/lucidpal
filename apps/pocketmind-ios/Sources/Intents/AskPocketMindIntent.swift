import AppIntents

// MARK: - Errors

enum SiriQueryError: Error, LocalizedError {
    case emptyQuery

    var errorDescription: String? {
        switch self {
        case .emptyQuery: return "Please provide a question for PocketMind."
        }
    }
}

// MARK: - Intent

/// Siri intent — user says "Ask PocketMind [query]".
/// The query is stored in UserDefaults; PocketMindApp picks it up
/// when the scene becomes active and forwards it to ChatViewModel.
struct AskPocketMindIntent: AppIntent {

    // MARK: - Metadata

    static var title: LocalizedStringResource = "Ask PocketMind"
    static var description = IntentDescription("Ask your on-device AI assistant a question")

    /// iOS opens the app after perform() returns.
    static var openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(title: "Question",
               description: "What would you like to ask PocketMind?",
               requestValueDialog: IntentDialog("What would you like to ask?"))
    var query: String

    // MARK: - Execution

    func perform() async throws -> some IntentResult {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SiriQueryError.emptyQuery
        }
        UserDefaults.standard.set(query, forKey: "pm_siri_pending_query")
        return .result()
    }
}
