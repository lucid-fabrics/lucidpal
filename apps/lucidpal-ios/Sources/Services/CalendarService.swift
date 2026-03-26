import EventKit
import Foundation

/// Lightweight domain model for writable calendars — avoids leaking EKCalendar into upper layers.
struct CalendarInfo: Identifiable, Hashable, Sendable {
    let id: String      // EKCalendar.calendarIdentifier
    let title: String
}

/// Domain type replacing EKAuthorizationStatus — removes EventKit dependency from SettingsViewModel and the protocol.
enum CalendarAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case restricted
    case denied
    case fullAccess
    case writeOnly
}

/// Lightweight domain model for calendar events — prevents EKEvent from leaking into upper layers.
struct CalendarEventInfo: Sendable {
    let eventIdentifier: String?
    let title: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String?
    let location: String?
    /// True when the event belongs to a recurring series.
    let isRecurring: Bool

    // swiftlint:disable:next line_length
    init(eventIdentifier: String?, title: String?, startDate: Date, endDate: Date, isAllDay: Bool, calendarTitle: String?, location: String? = nil, isRecurring: Bool = false) {
        self.eventIdentifier = eventIdentifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarTitle = calendarTitle
        self.location = location
        self.isRecurring = isRecurring
    }
}

// CalendarService is a pure data-access service — it holds no observable UI state.
// SettingsViewModel owns @Published calendarAuthStatus and syncs it manually after
// requestAccess() returns, keeping the observable layer entirely in ViewModels.
@MainActor
final class CalendarService {
    // Safety: `store` is only ever accessed from the MainActor (CalendarService is @MainActor),
    // and EKEventStore is documented as internally thread-safe for concurrent reads.
    // nonisolated(unsafe) is required because deinit is nonisolated in Swift 6.
    nonisolated(unsafe) private let store = EKEventStore()

    private(set) var authorizationStatus: CalendarAuthorizationStatus = .notDetermined

    private static let eventFetchLimit = 50

    private static let eventFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    init() {
        authorizationStatus = Self.mapStatus(EKEventStore.authorizationStatus(for: .event))
    }

    private static func mapStatus(_ s: EKAuthorizationStatus) -> CalendarAuthorizationStatus {
        switch s {
        case .notDetermined: return .notDetermined
        case .restricted:    return .restricted
        case .denied:        return .denied
        case .fullAccess:    return .fullAccess
        case .writeOnly:     return .writeOnly
        @unknown default:    return .notDetermined
        }
    }

    private static func mapEvent(_ event: EKEvent) -> CalendarEventInfo {
        CalendarEventInfo(
            eventIdentifier: event.eventIdentifier,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            calendarTitle: event.calendar?.title,
            location: event.location.flatMap { $0.isEmpty ? nil : $0 },
            isRecurring: event.hasRecurrenceRules
        )
    }

    // MARK: - Authorization

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            authorizationStatus = Self.mapStatus(EKEventStore.authorizationStatus(for: .event))
            return granted
        } catch {
            #if DEBUG
            print("[CalendarService] requestAccess failed: \(error)")
            #endif
            return false
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .fullAccess
    }

    // MARK: - Calendar metadata

    /// All user-writable calendars as domain objects.
    func writableCalendars() -> [CalendarInfo] {
        guard isAuthorized else { return [] }
        return store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .sorted { $0.title < $1.title }
            .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title) }
    }

    /// The system default calendar for new events.
    func defaultCalendarInfo() -> CalendarInfo? {
        guard let cal = store.defaultCalendarForNewEvents else { return nil }
        return CalendarInfo(id: cal.calendarIdentifier, title: cal.title)
    }

    /// Calendar name for a saved event identifier — used to populate preview cards.
    func calendarName(forEventIdentifier identifier: String) -> String? {
        store.event(withIdentifier: identifier)?.calendar?.title
    }

    // MARK: - Event queries

    /// Fetches events and formats them as a prompt-ready string.
    /// Refreshes authorization status on every call to detect runtime revocation.
    /// Caps at 50 events to prevent LLM context overflow.
    func fetchEvents(from start: Date = .now, days: Int = 7) -> String {
        authorizationStatus = Self.mapStatus(EKEventStore.authorizationStatus(for: .event))
        guard isAuthorized else { return "" }

        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(Self.eventFetchLimit)

        if events.isEmpty {
            return "No events in the next \(days) days."
        }
        return events.map { Self.formatEvent($0) }.joined(separator: "\n")
    }

    /// Searches for events within a ±windowDays window around today.
    /// Default is 180 days (±6 months) to cover typical planning horizons —
    /// e.g. "delete my summer vacation" needs to reach events months away.
    static let defaultSearchWindowDays = 180
    func findEvents(matching title: String, windowDays: Int = CalendarService.defaultSearchWindowDays) -> [CalendarEventInfo] {
        guard isAuthorized else { return [] }
        let windowStart = Calendar.current.date(byAdding: .day, value: -windowDays, to: .now) ?? .now
        let windowEnd   = Calendar.current.date(byAdding: .day, value: windowDays, to: .now) ?? .now
        let predicate = store.predicateForEvents(withStart: windowStart, end: windowEnd, calendars: nil)
        let query = title.lowercased()
        return store.events(matching: predicate)
            .filter { ($0.title ?? "").lowercased().contains(query) }
            .map(Self.mapEvent)
    }

    private static func formatEvent(_ event: EKEvent) -> String {
        let start = eventFormatter.string(from: event.startDate)
        let end = eventFormatter.string(from: event.endDate)
        let title = event.title ?? "Untitled"
        let cal = event.calendar?.title ?? ""
        let location = event.location.map { " @ \($0)" } ?? ""
        return "- \(title)\(location): \(start) → \(end) [\(cal)]"
    }

    /// Returns events overlapping the given window, optionally excluding one by identifier.
    func findConflicts(start: Date, end: Date, excludingIdentifier: String? = nil) -> [CalendarEventInfo] {
        guard isAuthorized else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).filter { event in
            if let id = excludingIdentifier, event.eventIdentifier == id { return false }
            return event.startDate < end && event.endDate > start
        }.map(Self.mapEvent)
    }

    /// Returns events in a date range — used for bulk operations.
    func events(in start: Date, end: Date) -> [CalendarEventInfo] {
        guard isAuthorized else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map(Self.mapEvent)
    }

    // MARK: - Mutations

    /// Deletes the event with the given identifier.
    func deleteEvent(identifier: String) throws {
        authorizationStatus = Self.mapStatus(EKEventStore.authorizationStatus(for: .event))
        guard isAuthorized else { throw CalendarError.notAuthorized }
        guard let event = store.event(withIdentifier: identifier) else {
            throw CalendarError.eventNotFound
        }
        // For recurring events, remove only this instance; series is managed by user in Calendar app.
        try store.remove(event, span: .thisEvent)
    }

    // swiftlint:disable cyclomatic_complexity
    /// Applies a PendingCalendarUpdate to an existing event. Returns the resulting preview state.
    func applyUpdate(_ update: PendingCalendarUpdate, to identifier: String) throws -> CalendarEventPreview.PreviewState {
        authorizationStatus = Self.mapStatus(EKEventStore.authorizationStatus(for: .event))
        guard isAuthorized else { throw CalendarError.notAuthorized }
        guard let event = store.event(withIdentifier: identifier) else {
            throw CalendarError.eventNotFound
        }

        let titleChanged = update.title != nil
        let datesChanged = update.start != nil || update.end != nil

        if let t = update.title { event.title = t }
        if let s = update.start { event.startDate = s }
        if let e = update.end { event.endDate = e }
        if let l = update.location, !l.isEmpty { event.location = l }
        if let n = update.notes, !n.isEmpty { event.notes = n }
        if let m = update.reminderMinutes {
            // Copy to local array before iterating to avoid mutating the collection in-place.
            let existingAlarms = event.alarms ?? []
            existingAlarms.forEach { event.removeAlarm($0) }
            event.addAlarm(EKAlarm(relativeOffset: -TimeInterval(m * 60)))
        }
        if let a = update.isAllDay { event.isAllDay = a }
        if let recurrence = update.recurrence {
            let freq: EKRecurrenceFrequency
            switch recurrence.lowercased() {
            case "daily":   freq = .daily
            case "weekly":  freq = .weekly
            case "monthly": freq = .monthly
            default:        freq = .yearly
            }
            event.recurrenceRules = [EKRecurrenceRule(recurrenceWith: freq, interval: 1, end: nil)]
        }

        try store.save(event, span: .thisEvent)
        return datesChanged && !titleChanged ? .rescheduled : .updated
    }
    // swiftlint:enable cyclomatic_complexity

    /// Creates and saves a calendar event. Returns the event identifier on success.
    @discardableResult
    func createEvent(
        title: String,
        start: Date,
        end: Date,
        location: String? = nil,
        notes: String? = nil,
        reminderMinutes: Int? = nil,
        calendarIdentifier: String? = nil,
        isAllDay: Bool = false,
        recurrence: String? = nil,
        recurrenceEnd: Date? = nil
    ) throws -> String {
        authorizationStatus = Self.mapStatus(EKEventStore.authorizationStatus(for: .event))
        guard isAuthorized else { throw CalendarError.notAuthorized }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.isAllDay = isAllDay
        event.startDate = start
        // All-day events require endDate = day after startDate in EventKit.
        event.endDate = isAllDay ? (Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start) : end
        if let location, !location.isEmpty { event.location = location }
        if let notes, !notes.isEmpty { event.notes = notes }
        if let minutes = reminderMinutes {
            event.addAlarm(EKAlarm(relativeOffset: -TimeInterval(minutes * 60)))
        }
        if let id = calendarIdentifier, let cal = store.calendar(withIdentifier: id) {
            event.calendar = cal
        } else {
            event.calendar = store.defaultCalendarForNewEvents
        }
        if let recurrence {
            let freq: EKRecurrenceFrequency
            switch recurrence.lowercased() {
            case "daily":   freq = .daily
            case "weekly":  freq = .weekly
            case "monthly": freq = .monthly
            default:        freq = .yearly
            }
            let ruleEnd = recurrenceEnd.map { EKRecurrenceEnd(end: $0) }
            event.recurrenceRules = [EKRecurrenceRule(
                recurrenceWith: freq,
                interval: 1,
                end: ruleEnd
            )]
        }

        // .thisEvent is correct for new events — the recurrence series is defined by the rule, not the span.
        try store.save(event, span: .thisEvent)
        return event.eventIdentifier ?? ""
    }
}
