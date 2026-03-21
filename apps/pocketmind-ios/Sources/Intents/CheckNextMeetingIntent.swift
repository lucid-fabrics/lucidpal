import AppIntents
import EventKit
import Foundation

/// Shortcuts-compatible intent — returns details of the next upcoming calendar event.
struct CheckNextMeetingIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Next Meeting"
    static let description = IntentDescription("Get details of your next calendar event")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let store = EKEventStore()

        // Check authorization
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else {
            return .result(value: "", dialog: "Calendar access not granted. Please enable in Settings.")
        }

        // Find next event (within next 7 days)
        let now = Date.now
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: now, end: weekFromNow, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { $0.startDate >= now }
            .sorted { $0.startDate < $1.startDate }

        guard let nextEvent = events.first else {
            return .result(value: "", dialog: "No upcoming events in the next 7 days.")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let title = nextEvent.title ?? "Untitled"
        let startStr = formatter.string(from: nextEvent.startDate)
        let location = nextEvent.location.flatMap { $0.isEmpty ? nil : " at \($0)" } ?? ""

        let response = "\(title)\(location) — \(startStr)"
        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}
