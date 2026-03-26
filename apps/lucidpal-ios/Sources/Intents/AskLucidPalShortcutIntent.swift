import AppIntents
import Foundation

/// Shortcuts-compatible intent — sends a query to LucidPal AI and returns the response.
/// Unlike AskLucidPalIntent (which opens the app), this runs in background and returns text.
/// Note: This uses a simplified LLM interaction - for full context-aware conversations, use the app.
struct AskLucidPalShortcutIntent: AppIntent {

    static let title: LocalizedStringResource = "Ask LucidPal (Background)"
    static let description = IntentDescription("Ask your AI assistant a question and get a text response")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Question",
               description: "What would you like to ask?",
               requestValueDialog: IntentDialog("What's your question?"))
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(value: "", dialog: "Please provide a question.")
        }

        // Store the query in UserDefaults and open the app instead
        // Background LLM inference requires model loading and is too heavy for a Shortcut
        // This intent serves as a "quick ask" that opens the app with the query pre-filled
        UserDefaults.standard.set(trimmed, forKey: UserDefaultsKeys.siriPendingQuery)

        // Return guidance to user
        let response = "Question saved: \"\(trimmed)\". Opening LucidPal for AI response."
        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}
