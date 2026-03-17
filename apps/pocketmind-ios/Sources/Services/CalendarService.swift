import EventKit
import Foundation

// CalendarService is a pure data-access service — it holds no observable UI state.
// SettingsViewModel owns @Published calendarAuthStatus and syncs it manually after
// requestAccess() returns, keeping the observable layer entirely in ViewModels.
@MainActor
final class CalendarService {
    // nonisolated(unsafe): EKEventStore is documented as thread-safe for read operations.
    // Marking it nonisolated(unsafe) allows background query offloading below.
    nonisolated(unsafe) let store = EKEventStore()

    private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined

    // Reuse formatter — DateFormatter is expensive to construct
    private static let eventFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        } catch {
            #if DEBUG
            print("[CalendarService] requestAccess failed: \(error)")
            #endif
            return false
        }
    }

    var isAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }

    /// Fetches events and formats them as a prompt-ready string.
    /// - Refreshes authorization status on every call to detect runtime revocation.
    /// - Caps at 50 events to prevent LLM context overflow.
    func fetchEvents(from start: Date = .now, days: Int = 7) -> String {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        guard isAuthorized else { return "" }

        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(50)

        if events.isEmpty {
            return "No events in the next \(days) days."
        }
        return events.map { Self.formatEvent($0) }.joined(separator: "\n")
    }

    private static func formatEvent(_ event: EKEvent) -> String {
        let start = eventFormatter.string(from: event.startDate)
        let end = eventFormatter.string(from: event.endDate)
        let title = event.title ?? "Untitled"
        let cal = event.calendar?.title ?? ""
        let location = event.location.map { " @ \($0)" } ?? ""
        return "- \(title)\(location): \(start) → \(end) [\(cal)]"
    }

    /// Creates and saves a calendar event. Returns the event identifier on success.
    @discardableResult
    func createEvent(title: String, start: Date, end: Date, location: String? = nil, notes: String? = nil) throws -> String {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        guard isAuthorized else {
            throw CalendarError.notAuthorized
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        if let location, !location.isEmpty { event.location = location }
        if let notes, !notes.isEmpty { event.notes = notes }
        event.calendar = store.defaultCalendarForNewEvents

        try store.save(event, span: .thisEvent)
        return event.eventIdentifier ?? ""
    }
}

enum CalendarError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        "Calendar access is not authorized. Enable it in Settings."
    }
}
