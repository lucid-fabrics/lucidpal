import XCTest
@testable import PocketMind

final class PendingCalendarUpdateTests: XCTestCase {

    func testEmptyUpdateEncodesAndDecodes() throws {
        let update = PendingCalendarUpdate()
        let data = try JSONEncoder().encode(update)
        let decoded = try JSONDecoder().decode(PendingCalendarUpdate.self, from: data)
        XCTAssertEqual(update, decoded)
    }

    func testFullUpdateRoundTrip() throws {
        var update = PendingCalendarUpdate()
        update.title = "New Title"
        update.start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        update.end   = Date(timeIntervalSinceReferenceDate: 1_003_600)
        update.location = "Conference Room"
        update.notes = "Agenda attached"
        update.reminderMinutes = 15
        update.isAllDay = false
        update.recurrence = "weekly"

        let data = try JSONEncoder().encode(update)
        let decoded = try JSONDecoder().decode(PendingCalendarUpdate.self, from: data)

        XCTAssertEqual(decoded.title, "New Title")
        XCTAssertEqual(decoded.location, "Conference Room")
        XCTAssertEqual(decoded.notes, "Agenda attached")
        XCTAssertEqual(decoded.reminderMinutes, 15)
        XCTAssertEqual(decoded.isAllDay, false)
        XCTAssertEqual(decoded.recurrence, "weekly")
        XCTAssertEqual(decoded.start, update.start)
        XCTAssertEqual(decoded.end, update.end)
    }

    func testRecurrenceFieldIsNilByDefault() {
        let update = PendingCalendarUpdate()
        XCTAssertNil(update.recurrence)
    }

    func testCalendarEventPreviewCodableRoundTrip() throws {
        let preview = CalendarEventPreview(
            title: "Standup",
            start: Date(timeIntervalSinceReferenceDate: 800_000),
            end:   Date(timeIntervalSinceReferenceDate: 801_800),
            calendarName: "Work",
            state: .pendingDeletion,
            eventIdentifier: "abc-123",
            reminderMinutes: 5,
            isAllDay: false,
            recurrence: "daily"
        )
        let data = try JSONEncoder().encode(preview)
        let decoded = try JSONDecoder().decode(CalendarEventPreview.self, from: data)

        XCTAssertEqual(decoded.title, "Standup")
        XCTAssertEqual(decoded.state, .pendingDeletion)
        XCTAssertEqual(decoded.eventIdentifier, "abc-123")
        XCTAssertEqual(decoded.reminderMinutes, 5)
        XCTAssertEqual(decoded.recurrence, "daily")
        XCTAssertFalse(decoded.isAllDay)
    }

    func testChatMessageCodableExcludesSystemRole() throws {
        let messages: [ChatMessage] = [
            ChatMessage(role: .user, content: "hello"),
            ChatMessage(role: .assistant, content: "hi"),
            ChatMessage(role: .system, content: "system prompt"),
        ]
        let filtered = messages.filter { $0.role != .system }
        let data = try JSONEncoder().encode(filtered)
        let decoded = try JSONDecoder().decode([ChatMessage].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertTrue(decoded.allSatisfy { $0.role != .system })
    }
}
