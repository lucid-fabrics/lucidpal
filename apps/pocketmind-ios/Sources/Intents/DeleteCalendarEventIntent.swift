import AppIntents
import EventKit
import OSLog
import SwiftUI

private let intentLogger = Logger(subsystem: "com.pocketmind", category: "DeleteCalendarEventIntent")

// MARK: - Shared undo store

private let undoDefaultsKey = "pm_siri_last_deleted_event"

struct SiriDeletedEvent: Codable {
    let title: String
    let start: Date
    let end: Date
    let calendarIdentifier: String?
    let isAllDay: Bool
    let location: String?
    let notes: String?
}

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

        // Show event card + ask for confirmation
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

        // Save for undo
        let undoData = SiriDeletedEvent(
            title: event.title,
            start: event.startDate,
            end: event.endDate,
            calendarIdentifier: event.calendar.calendarIdentifier,
            isAllDay: event.isAllDay,
            location: event.location,
            notes: event.notes
        )
        do {
            let encoded = try JSONEncoder().encode(undoData)
            UserDefaults.standard.set(encoded, forKey: undoDefaultsKey)
        } catch {
            print("[DeleteCalendarEventIntent] Failed to encode undo data: \(error)")
        }

        // Delete
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
    /// Throws a localised error string when nothing matches.
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

// MARK: - UndoLastDeletionIntent

/// Siri intent: "Undo last deletion in PocketMind"
/// Restores the most recently Siri-deleted event, with confirmation.
struct UndoLastDeletionIntent: AppIntent {

    static let title: LocalizedStringResource = "Undo Last Deletion"
    static let description = IntentDescription("Restore the last event deleted via PocketMind")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let data = UserDefaults.standard.data(forKey: undoDefaultsKey) else {
            return .result(dialog: "There's nothing to undo.", view: EmptyView())
        }
        let deleted: SiriDeletedEvent
        do {
            deleted = try JSONDecoder().decode(SiriDeletedEvent.self, from: data)
        } catch {
            intentLogger.error("Failed to decode undo data: \(error)")
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

        // Show confirmation with the event to restore
        try await requestConfirmation(
            output: .result(
                dialog: IntentDialog(stringLiteral: "Restore \"\(deleted.title)\"?"),
                view: SiriEventCard(
                    title: deleted.title,
                    start: deleted.start,
                    end: deleted.end,
                    calendarName: nil,
                    isAllDay: deleted.isAllDay,
                    deleted: false
                )
            )
        )

        try recreateEvent(from: deleted, in: store)

        // Clear undo data
        UserDefaults.standard.removeObject(forKey: undoDefaultsKey)

        return .result(
            dialog: IntentDialog(stringLiteral: "\"\(deleted.title)\" has been restored."),
            view: SiriEventCard(
                title: deleted.title,
                start: deleted.start,
                end: deleted.end,
                calendarName: nil,
                isAllDay: deleted.isAllDay,
                deleted: false
            )
        )
    }

    /// Reconstructs an EKEvent from a `SiriDeletedEvent` snapshot and saves it to `store`.
    private func recreateEvent(from deleted: SiriDeletedEvent, in store: EKEventStore) throws {
        let event = EKEvent(eventStore: store)
        event.title = deleted.title
        event.startDate = deleted.start
        event.endDate = deleted.end
        event.isAllDay = deleted.isAllDay
        event.location = deleted.location
        event.notes = deleted.notes
        if let calID = deleted.calendarIdentifier,
           let cal = store.calendar(withIdentifier: calID) {
            event.calendar = cal
        } else {
            event.calendar = store.defaultCalendarForNewEvents
        }
        try store.save(event, span: .thisEvent)
    }
}

// MARK: - Siri snippet view

struct SiriEventCard: View {
    let title: String
    let start: Date
    let end: Date
    let calendarName: String?
    let isAllDay: Bool
    let deleted: Bool

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        return f
    }()
    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d"
        return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack(spacing: 1) {
                Text(Self.monthFmt.string(from: start).uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(deleted ? Color.gray : Color.red)
                Text(Self.dayFmt.string(from: start))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(deleted ? .secondary : .primary)
                    .padding(.bottom, 4)
            }
            .frame(width: 44)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(deleted ? .secondary : .primary)
                    .strikethrough(deleted, color: .secondary)
                    .lineLimit(1)
                Text(isAllDay ? "All day" : "\(Self.timeFmt.string(from: start)) – \(Self.timeFmt.string(from: end))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let cal = calendarName {
                    Text(cal)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if deleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(deleted ? 0.7 : 1)
    }
}
