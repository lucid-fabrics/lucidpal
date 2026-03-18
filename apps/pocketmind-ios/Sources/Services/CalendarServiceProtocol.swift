import Foundation

/// Abstracts CalendarService for dependency injection in CalendarActionController.
/// Conforming CalendarService to this protocol enables unit testing without a live EKEventStore.
@MainActor
protocol CalendarServiceProtocol: AnyObject {
    var isAuthorized: Bool { get }
    var authorizationStatus: CalendarAuthorizationStatus { get }
    @discardableResult func requestAccess() async -> Bool
    func writableCalendars() -> [CalendarInfo]
    func fetchEvents(from start: Date, days: Int) -> String
    func findEvents(matching title: String, windowDays: Int) -> [CalendarEventInfo]
    func findConflicts(start: Date, end: Date, excludingIdentifier: String?) -> [CalendarEventInfo]
    func events(in start: Date, end: Date) -> [CalendarEventInfo]
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
    ) throws -> String
    func deleteEvent(identifier: String) throws
    func applyUpdate(_ update: PendingCalendarUpdate, to identifier: String) throws -> CalendarEventPreview.PreviewState
    func calendarName(forEventIdentifier identifier: String) -> String?
    func defaultCalendarInfo() -> CalendarInfo?
}

extension CalendarService: CalendarServiceProtocol {}
