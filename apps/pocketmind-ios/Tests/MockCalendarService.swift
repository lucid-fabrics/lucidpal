import Foundation
@testable import PocketMind

/// In-memory mock conforming to CalendarServiceProtocol for unit tests.
/// Tests control authorization and the events returned by each method.
@MainActor
final class MockCalendarService: CalendarServiceProtocol {
    var isAuthorized: Bool = true
    var authorizationStatus: CalendarAuthorizationStatus = .fullAccess
    var requestAccessResult: Bool = true
    var stubbedEvents: [CalendarEventInfo] = []
    var stubbedConflicts: [CalendarEventInfo] = []
    var stubbedFetchEvents: String = ""
    var createdEvents: [(title: String, start: Date, end: Date, isAllDay: Bool)] = []
    var deletedIdentifiers: [String] = []
    var appliedUpdates: [(PendingCalendarUpdate, String)] = []
    var shouldThrowOnDelete = false
    var shouldThrowOnApplyUpdate = false

    func requestAccess() async -> Bool {
        isAuthorized = requestAccessResult
        authorizationStatus = requestAccessResult ? .fullAccess : .denied
        return requestAccessResult
    }

    func writableCalendars() -> [CalendarInfo] {
        [CalendarInfo(id: "default", title: "Calendar")]
    }

    func fetchEvents(from start: Date, days: Int) -> String {
        stubbedFetchEvents
    }

    func findEvents(matching title: String, windowDays: Int) -> [CalendarEventInfo] {
        stubbedEvents
    }

    func findConflicts(start: Date, end: Date, excludingIdentifier: String?) -> [CalendarEventInfo] {
        stubbedConflicts
    }

    func events(in start: Date, end: Date) -> [CalendarEventInfo] {
        stubbedEvents
    }

    @discardableResult
    func createEvent(
        title: String,
        start: Date,
        end: Date,
        location: String?,
        notes: String?,
        reminderMinutes: Int?,
        calendarIdentifier: String?,
        isAllDay: Bool,
        recurrence: String?,
        recurrenceEnd: Date?
    ) throws -> String {
        createdEvents.append((title: title, start: start, end: end, isAllDay: isAllDay))
        return "mock-id-\(createdEvents.count)"
    }

    func deleteEvent(identifier: String) throws {
        if shouldThrowOnDelete { throw CalendarError.eventNotFound }
        deletedIdentifiers.append(identifier)
    }

    func applyUpdate(_ update: PendingCalendarUpdate, to identifier: String) throws -> CalendarEventPreview.PreviewState {
        if shouldThrowOnApplyUpdate { throw CalendarError.eventNotFound }
        appliedUpdates.append((update, identifier))
        let datesChanged = update.start != nil || update.end != nil
        let titleChanged = update.title != nil
        return datesChanged && !titleChanged ? .rescheduled : .updated
    }

    func calendarName(forEventIdentifier identifier: String) -> String? {
        "Test Calendar"
    }

    func defaultCalendarInfo() -> CalendarInfo? {
        CalendarInfo(id: "default", title: "Calendar")
    }
}
