import XCTest
@testable import PocketMind

@MainActor
final class CalendarServiceProtocolTests: XCTestCase {

    var service: MockCalendarService!

    override func setUp() async throws {
        service = MockCalendarService()
    }

    // MARK: - writableCalendars

    func testWritableCalendarsReturnsDefaultCalendar() {
        let calendars = service.writableCalendars()
        XCTAssertFalse(calendars.isEmpty)
    }

    func testWritableCalendarsContainsCalendarTitle() {
        let calendars = service.writableCalendars()
        XCTAssertEqual(calendars.first?.title, "Calendar")
    }

    // MARK: - findConflicts

    func testFindConflictsReturnsStubbedConflicts() {
        let conflict = MockCalendarService.makeConflict(
            title: "Conflict",
            start: Date(),
            end: Date(timeIntervalSinceNow: 3600)
        )
        service.stubbedConflicts = [conflict]
        let result = service.findConflicts(
            start: Date(),
            end: Date(timeIntervalSinceNow: 3600),
            excludingIdentifier: nil
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Conflict")
    }

    func testFindConflictsWithNoStubbedConflictsReturnsEmpty() {
        let result = service.findConflicts(
            start: Date(),
            end: Date(timeIntervalSinceNow: 3600),
            excludingIdentifier: nil
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testFindConflictsStubbedRecurringFlag() {
        let conflict = MockCalendarService.makeConflict(
            title: "Weekly",
            start: Date(),
            end: Date(timeIntervalSinceNow: 1800),
            isRecurring: true
        )
        service.stubbedConflicts = [conflict]
        let result = service.findConflicts(start: Date(), end: Date(timeIntervalSinceNow: 3600), excludingIdentifier: nil)
        XCTAssertTrue(result.first?.isRecurring == true)
    }

    // MARK: - createEvent

    func testCreateEventRecordsCreatedEvent() throws {
        let start = Date(timeIntervalSinceNow: 3600)
        let end = Date(timeIntervalSinceNow: 7200)
        _ = try service.createEvent(
            title: "Test",
            start: start,
            end: end,
            location: nil,
            notes: nil,
            reminderMinutes: nil,
            calendarIdentifier: nil,
            isAllDay: false,
            recurrence: nil,
            recurrenceEnd: nil
        )
        XCTAssertEqual(service.createdEvents.count, 1)
        XCTAssertEqual(service.createdEvents.first?.title, "Test")
    }

    func testCreateEventReturnsIncrementingMockId() throws {
        _ = try service.createEvent(title: "A", start: Date(), end: Date(), location: nil, notes: nil, reminderMinutes: nil, calendarIdentifier: nil, isAllDay: false, recurrence: nil, recurrenceEnd: nil)
        let id = try service.createEvent(title: "B", start: Date(), end: Date(), location: nil, notes: nil, reminderMinutes: nil, calendarIdentifier: nil, isAllDay: false, recurrence: nil, recurrenceEnd: nil)
        XCTAssertEqual(id, "mock-id-2")
    }

    func testCreateEventThrowsWhenConfigured() {
        service.shouldThrowOnCreate = true
        XCTAssertThrowsError(
            try service.createEvent(
                title: "T",
                start: Date(),
                end: Date(),
                location: nil,
                notes: nil,
                reminderMinutes: nil,
                calendarIdentifier: nil,
                isAllDay: false,
                recurrence: nil,
                recurrenceEnd: nil
            )
        )
    }

    func testCreateEventDoesNotRecordOnThrow() {
        service.shouldThrowOnCreate = true
        _ = try? service.createEvent(title: "T", start: Date(), end: Date(), location: nil, notes: nil, reminderMinutes: nil, calendarIdentifier: nil, isAllDay: false, recurrence: nil, recurrenceEnd: nil)
        XCTAssertTrue(service.createdEvents.isEmpty)
    }

    // MARK: - deleteEvent

    func testDeleteEventRecordsDeletedIdentifier() throws {
        try service.deleteEvent(identifier: "evt-123")
        XCTAssertTrue(service.deletedIdentifiers.contains("evt-123"))
    }

    func testDeleteEventThrowsWhenConfigured() {
        service.shouldThrowOnDelete = true
        XCTAssertThrowsError(try service.deleteEvent(identifier: "evt-123"))
    }

    func testDeleteEventDoesNotRecordOnThrow() {
        service.shouldThrowOnDelete = true
        _ = try? service.deleteEvent(identifier: "evt-123")
        XCTAssertTrue(service.deletedIdentifiers.isEmpty)
    }

    // MARK: - applyUpdate

    func testApplyUpdateReturnsTitleOnlyState() throws {
        var update = PendingCalendarUpdate()
        update.title = "New Title"
        let state = try service.applyUpdate(update, to: "evt-123")
        XCTAssertEqual(state, .updated)
    }

    func testApplyUpdateReturnsRescheduledForDateOnlyChange() throws {
        var update = PendingCalendarUpdate()
        update.start = Date(timeIntervalSinceNow: 3600)
        update.end = Date(timeIntervalSinceNow: 7200)
        let state = try service.applyUpdate(update, to: "evt-123")
        XCTAssertEqual(state, .rescheduled)
    }

    func testApplyUpdateReturnsUpdatedWhenBothTitleAndDatesChange() throws {
        // MockCalendarService: rescheduled only when dates changed AND title did NOT change
        var update = PendingCalendarUpdate()
        update.title = "New Title"
        update.start = Date(timeIntervalSinceNow: 3600)
        update.end = Date(timeIntervalSinceNow: 7200)
        let state = try service.applyUpdate(update, to: "evt-123")
        XCTAssertEqual(state, .updated)
    }

    func testApplyUpdateThrowsWhenConfigured() {
        service.shouldThrowOnApplyUpdate = true
        var update = PendingCalendarUpdate()
        update.title = "Test"
        XCTAssertThrowsError(try service.applyUpdate(update, to: "evt-123"))
    }

    func testApplyUpdateRecordsAppliedUpdate() throws {
        var update = PendingCalendarUpdate()
        update.title = "Updated"
        _ = try service.applyUpdate(update, to: "evt-abc")
        XCTAssertEqual(service.appliedUpdates.count, 1)
        XCTAssertEqual(service.appliedUpdates.first?.1, "evt-abc")
    }

    // MARK: - calendarName

    func testCalendarNameReturnsStubbed() {
        service.stubbedCalendarNames = ["evt-001": "Work"]
        XCTAssertEqual(service.calendarName(forEventIdentifier: "evt-001"), "Work")
    }

    func testCalendarNameReturnsNilForUnknownIdentifier() {
        XCTAssertNil(service.calendarName(forEventIdentifier: "unknown-id"))
    }

    // MARK: - defaultCalendarInfo

    func testDefaultCalendarInfoReturnsDefaultCalendar() throws {
        let info = try XCTUnwrap(service.defaultCalendarInfo())
        XCTAssertEqual(info.title, "Calendar")
    }

    func testDefaultCalendarInfoHasDefaultId() {
        let info = service.defaultCalendarInfo()
        XCTAssertEqual(info?.id, "default")
    }

    // MARK: - requestAccess

    func testRequestAccessSetsFullAccessOnSuccess() async {
        service.requestAccessResult = true
        let result = await service.requestAccess()
        XCTAssertTrue(result)
        XCTAssertEqual(service.authorizationStatus, .fullAccess)
    }

    func testRequestAccessSetsDeniedOnFailure() async {
        service.requestAccessResult = false
        let result = await service.requestAccess()
        XCTAssertFalse(result)
        XCTAssertEqual(service.authorizationStatus, .denied)
    }

    func testRequestAccessUpdatesIsAuthorized() async {
        service.requestAccessResult = true
        _ = await service.requestAccess()
        XCTAssertTrue(service.isAuthorized)
    }

    // MARK: - events(in:end:)

    func testEventsInRangeReturnsStubbedEvents() {
        let event = CalendarEventInfo(
            eventIdentifier: "e1",
            title: "Meeting",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 3600),
            isAllDay: false,
            calendarTitle: "Work",
            isRecurring: false
        )
        service.stubbedEvents = [event]
        let result = service.events(in: Date(), end: Date(timeIntervalSinceNow: 7200))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Meeting")
    }

    func testEventsInRangeReturnsEmptyWhenNoStubs() {
        let result = service.events(in: Date(), end: Date(timeIntervalSinceNow: 3600))
        XCTAssertTrue(result.isEmpty)
    }
}
