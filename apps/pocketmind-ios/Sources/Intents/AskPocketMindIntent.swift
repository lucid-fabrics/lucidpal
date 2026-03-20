import AppIntents

// MARK: - Siri Pending Event

struct SiriPendingEvent: Codable, Identifiable {
    let id: UUID
    let title: String
    let date: Date

    init(title: String, date: Date) {
        self.id = UUID()
        self.title = title
        self.date = date
    }
}

private let pendingEventDefaultsKey = UserDefaultsKeys.siriPendingEvent

// MARK: - Errors

enum SiriQueryError: Error, LocalizedError {
    case emptyQuery

    var errorDescription: String? {
        switch self {
        case .emptyQuery: return "Please provide a question for PocketMind."
        }
    }
}

// MARK: - AskPocketMindIntent

/// Siri intent — user says "Ask PocketMind [query]".
/// The query is stored in UserDefaults; PocketMindApp picks it up
/// when the scene becomes active and forwards it to ChatViewModel.
struct AskPocketMindIntent: AppIntent {

    static let title: LocalizedStringResource = "Ask PocketMind"
    static let description = IntentDescription("Ask your on-device AI assistant a question")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Question",
               description: "What would you like to ask PocketMind?",
               requestValueDialog: IntentDialog("What would you like to ask?"))
    var query: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SiriQueryError.emptyQuery }
        UserDefaults.standard.set(trimmed, forKey: UserDefaultsKeys.siriPendingQuery)
        return .result(dialog: "Opening PocketMind.")
    }
}

// MARK: - CheckCalendarIntent

/// Siri intent — user says "Check my PocketMind calendar".
/// Pre-seeds the query so Siri doesn't need a follow-up prompt.
struct CheckCalendarIntent: AppIntent {

    static let title: LocalizedStringResource = "Check My Calendar"
    static let description = IntentDescription("See what's on your calendar via PocketMind")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set("What's on my calendar today?", forKey: UserDefaultsKeys.siriPendingQuery)
        return .result(dialog: "Let me check your calendar.")
    }
}

// MARK: - AddCalendarEventIntent

/// Siri intent — user says "Add [event] to PocketMind".
/// Asks for event title and date/time if not provided, then opens the app with a pre-filled form.
struct AddCalendarEventIntent: AppIntent {

    static let title: LocalizedStringResource = "Add Calendar Event"
    static let description = IntentDescription("Add a new event to your calendar via PocketMind")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Event",
               description: "What event would you like to add?",
               requestValueDialog: IntentDialog("What would you like to add to your calendar?"))
    var event: String

    @Parameter(title: "Date",
               description: "When is the event?",
               requestValueDialog: IntentDialog("When is the event?"))
    var when: Date

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = event.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SiriQueryError.emptyQuery }
        let payload = SiriPendingEvent(title: trimmed, date: when)
        do {
            let encoded = try JSONEncoder().encode(payload)
            UserDefaults.standard.set(encoded, forKey: pendingEventDefaultsKey)
        } catch {
            print("[AddCalendarEventIntent] Failed to encode pending event: \(error)")
        }
        return .result(dialog: "Opening PocketMind to schedule \(trimmed).")
    }
}

// MARK: - FindFreeTimeIntent

/// Siri intent — user says "Find free time in PocketMind".
/// Pre-seeds a free-slot query for today.
struct FindFreeTimeIntent: AppIntent {

    static let title: LocalizedStringResource = "Find Free Time"
    static let description = IntentDescription("Find a free slot in your schedule via PocketMind")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set("Find a free 1-hour slot today", forKey: UserDefaultsKeys.siriPendingQuery)
        return .result(dialog: "Let me find a free slot for you.")
    }
}
