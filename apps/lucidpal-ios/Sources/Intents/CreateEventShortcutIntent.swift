import AppIntents
import EventKit
import Foundation

/// Shortcuts-compatible intent — creates a calendar event and returns confirmation.
/// Unlike AddCalendarEventIntent (which opens the app), this runs in background.
struct CreateEventShortcutIntent: AppIntent {

    static let title: LocalizedStringResource = "Create Event"
    static let description = IntentDescription("Create a calendar event directly from Shortcuts")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Event Title",
               description: "The name of the event",
               requestValueDialog: IntentDialog("What's the event title?"))
    var eventTitle: String

    @Parameter(title: "Start Time",
               description: "When the event starts",
               requestValueDialog: IntentDialog("When does it start?"))
    var startTime: Date

    @Parameter(title: "Duration (minutes)",
               description: "How long the event lasts",
               default: 60)
    var durationMinutes: Int

    @Parameter(title: "Location",
               description: "Event location (optional)")
    var location: String?

    @Parameter(title: "Notes",
               description: "Event notes (optional)")
    var notes: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Create \(\.$eventTitle) at \(\.$startTime) for \(\.$durationMinutes) minutes") {
            \.$location
            \.$notes
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let trimmed = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(value: "", dialog: "Event title cannot be empty.")
        }

        let endTime = startTime.addingTimeInterval(TimeInterval(durationMinutes * 60))

        // Direct EventKit access — CalendarService requires @MainActor but intents run off-main
        let store = EKEventStore()

        // Check authorization
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else {
            return .result(value: "", dialog: "Calendar access not granted. Please enable in Settings.")
        }

        // Create event
        let event = EKEvent(eventStore: store)
        event.title = trimmed
        event.startDate = startTime
        event.endDate = endTime
        event.calendar = store.defaultCalendarForNewEvents

        if let loc = location, !loc.isEmpty {
            event.location = loc
        }
        if let n = notes, !n.isEmpty {
            event.notes = n
        }

        do {
            try store.save(event, span: .thisEvent)
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let timeStr = formatter.string(from: startTime)
            return .result(
                value: event.eventIdentifier ?? "",
                dialog: "Created \"\(trimmed)\" at \(timeStr)."
            )
        } catch {
            return .result(value: "", dialog: "Failed to create event: \(error.localizedDescription)")
        }
    }
}
