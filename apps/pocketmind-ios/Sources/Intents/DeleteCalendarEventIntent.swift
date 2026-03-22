import AppIntents
import EventKit
import OSLog
import SwiftUI

private let intentLogger = Logger(subsystem: "app.pocketmind", category: "DeleteCalendarEventIntent")

// MARK: - DeleteCalendarEventIntent

/// Siri intent: "Delete [event] in PocketMind"
/// Shows the event card as a snippet, asks for confirmation, then deletes.
struct DeleteCalendarEventIntent: AppIntent {

    static let title: LocalizedStringResource = "Delete Calendar Event"
    static let description = IntentDescription("Delete an event from your calendar via PocketMind")
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Event",
        description: "The name of the event to delete",
        requestValueDialog: IntentDialog("Which event would you like to delete?")
    )
    var eventName: String

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Direct EventKit access — CalendarService requires @MainActor but intents run off-main
        let store = EKEventStore()
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await store.requestWriteOnlyAccessToEvents()
        } else {
            granted = try await store.requestAccess(to: .event)
        }
        guard granted else {
            return .result(dialog: "Calendar access is required. Please allow it in Settings.", view: EmptyView())
        }

        let event = try findMatchingEvent(named: eventName, in: store)

        try await requestConfirmation(
            output: .result(
                dialog: IntentDialog(stringLiteral: "Delete \"\(event.title)\"?"),
                view: SiriEventCard(
                    title: event.title,
                    start: event.startDate,
                    end: event.endDate,
                    calendarName: event.calendar.title,
                    isAllDay: event.isAllDay,
                    deleted: false
                )
            )
        )

        // Persist for undo before deleting
        SiriContextStore.write(SiriLastAction(
            type: .deleted,
            eventTitle: event.title,
            eventStart: event.startDate,
            eventEnd: event.endDate,
            calendarName: event.calendar.title,
            calendarIdentifier: event.calendar.calendarIdentifier,
            isAllDay: event.isAllDay,
            location: event.location,
            notes: event.notes,
            eventIdentifier: nil,
            timestamp: .now
        ))

        try store.remove(event, span: .thisEvent)

        return .result(
            dialog: IntentDialog(stringLiteral: "\"\(event.title)\" has been deleted."),
            view: SiriEventCard(
                title: event.title,
                start: event.startDate,
                end: event.endDate,
                calendarName: event.calendar.title,
                isAllDay: event.isAllDay,
                deleted: true
            )
        )
    }

    /// Searches ±1 day to +90 days for an event whose title contains `name`.
    /// Returns the soonest upcoming match, or the earliest past match if all are past.
    private func findMatchingEvent(named name: String, in store: EKEventStore) throws -> EKEvent {
        let now = Date()
        let past = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let future = Calendar.current.date(byAdding: .day, value: 90, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: past, end: future, calendars: nil)
        let matches = store.events(matching: predicate)
            .filter { $0.title.localizedCaseInsensitiveContains(name) }

        guard !matches.isEmpty else {
            throw NSError(
                domain: "DeleteCalendarEventIntent",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "I couldn't find an event named \"\(name)\"."]
            )
        }

        let sorted = matches.sorted { $0.startDate < $1.startDate }
        return sorted.first(where: { $0.startDate >= now }) ?? sorted[0]
    }
}

// MARK: - UndoLastActionIntent

/// Siri intent: "Undo my last PocketMind action"
/// Covers both in-app and Siri-initiated calendar changes:
///   - deleted event → restores it
///   - created event → deletes it (with confirmation)
///   - updated/rescheduled → informs the user (full field-level undo not yet supported)
struct UndoLastDeletionIntent: AppIntent {

    static let title: LocalizedStringResource = "Undo Last Action"
    static let description = IntentDescription("Undo the last calendar action taken in PocketMind")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let last = SiriContextStore.read() else {
            return .result(dialog: "There's nothing to undo.", view: EmptyView())
        }

        let store = EKEventStore()
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await store.requestWriteOnlyAccessToEvents()
        } else {
            granted = try await store.requestAccess(to: .event)
        }
        guard granted else {
            return .result(dialog: "Calendar access is required. Please allow it in Settings.", view: EmptyView())
        }

        switch last.type {
        case .deleted:
            try await requestConfirmation(
                output: .result(
                    dialog: IntentDialog(stringLiteral: "Restore \"\(last.eventTitle)\"?"),
                    view: SiriEventCard(
                        title: last.eventTitle, start: last.eventStart, end: last.eventEnd,
                        calendarName: last.calendarName, isAllDay: last.isAllDay, deleted: false
                    )
                )
            )
            let restored = EKEvent(eventStore: store)
            restored.title = last.eventTitle
            restored.startDate = last.eventStart
            restored.endDate = last.eventEnd
            restored.isAllDay = last.isAllDay
            restored.location = last.location
            restored.notes = last.notes
            if let calID = last.calendarIdentifier, let cal = store.calendar(withIdentifier: calID) {
                restored.calendar = cal
            } else {
                restored.calendar = store.defaultCalendarForNewEvents
            }
            try store.save(restored, span: .thisEvent)
            SiriContextStore.clear()
            return .result(
                dialog: IntentDialog(stringLiteral: "\"\(last.eventTitle)\" has been restored."),
                view: SiriEventCard(
                    title: last.eventTitle, start: last.eventStart, end: last.eventEnd,
                    calendarName: last.calendarName, isAllDay: last.isAllDay, deleted: false
                )
            )

        case .created:
            guard let identifier = last.eventIdentifier,
                  let event = store.event(withIdentifier: identifier) else {
                return .result(dialog: "That event no longer exists.", view: EmptyView())
            }
            try await requestConfirmation(
                output: .result(
                    dialog: IntentDialog(stringLiteral: "Delete \"\(last.eventTitle)\"?"),
                    view: SiriEventCard(
                        title: last.eventTitle, start: last.eventStart, end: last.eventEnd,
                        calendarName: last.calendarName, isAllDay: last.isAllDay, deleted: false
                    )
                )
            )
            try store.remove(event, span: .thisEvent)
            SiriContextStore.clear()
            return .result(
                dialog: IntentDialog(stringLiteral: "\"\(last.eventTitle)\" has been removed."),
                view: SiriEventCard(
                    title: last.eventTitle, start: last.eventStart, end: last.eventEnd,
                    calendarName: last.calendarName, isAllDay: last.isAllDay, deleted: true
                )
            )

        case .updated, .rescheduled:
            return .result(
                dialog: "I can't undo event edits yet — open PocketMind to make changes manually.",
                view: SiriEventCard(
                    title: last.eventTitle, start: last.eventStart, end: last.eventEnd,
                    calendarName: last.calendarName, isAllDay: last.isAllDay, deleted: false
                )
            )
        }
    }
}

