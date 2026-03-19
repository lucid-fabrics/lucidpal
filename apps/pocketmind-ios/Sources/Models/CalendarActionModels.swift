import Foundation

// MARK: - Action payload

struct CalendarActionPayload: Decodable {
    enum ActionType: String, Decodable {
        case create
        case update
        case delete
        case query
        case list
    }

    // Optional — small models often omit it; default to .create
    let action: ActionType?
    let title: String?         // required for create/update; omitted for delete
    let search: String?        // existing event title to find (update/delete)
    let start: Date?           // event start for create/update; range start for bulk delete
    let end: Date?             // event end for create/update; range end for bulk delete
    let location: String?
    let notes: String?
    let reminderMinutes: Int?  // minutes before event to trigger alarm
    let isAllDay: Bool?        // true for all-day events (holidays, birthdays)
    let recurrence: String?    // "daily" | "weekly" | "monthly" | "yearly"
    let recurrenceEnd: Date?   // optional end date for recurrence
    let durationMinutes: Int?  // for query: desired free slot length in minutes
}

// MARK: - Result

enum CalendarActionResult {
    case success(String, CalendarEventPreview)
    case bulkPending([CalendarEventPreview])          // multiple pending-deletion cards
    case queryResult([CalendarFreeSlot])              // free slot query — structured slots
    case listResult([CalendarEventPreview])           // event listing — tappable event cards
    case failure(String)
}

// MARK: - Protocol

/// Abstraction for executing LLM-emitted calendar action JSON.
/// Inject via `any CalendarActionControllerProtocol` in ChatViewModel for testability.
@MainActor
protocol CalendarActionControllerProtocol: AnyObject {
    func execute(json: String) async -> CalendarActionResult
}
