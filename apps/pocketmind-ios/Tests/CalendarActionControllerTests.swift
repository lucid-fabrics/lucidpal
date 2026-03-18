import XCTest
@testable import PocketMind

@MainActor
final class CalendarActionControllerTests: XCTestCase {
    var mock: MockCalendarService!
    var settings: AppSettings!
    var controller: CalendarActionController!

    override func setUp() {
        super.setUp()
        mock = MockCalendarService()
        settings = AppSettings()
        controller = CalendarActionController(calendarService: mock, settings: settings)
    }

    // MARK: - Create

    func testCreateEventSuccess() async {
        let json = #"{"action":"create","title":"Dentist","start":"2026-06-01T10:00:00","end":"2026-06-01T11:00:00"}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success, got \(result)")
        }
        XCTAssertEqual(preview.title, "Dentist")
        XCTAssertEqual(preview.state, .created)
        XCTAssertEqual(mock.createdEvents.count, 1)
    }

    func testCreateEventAllDay() async {
        let json = #"{"action":"create","title":"Holiday","start":"2026-07-04T00:00:00","end":"2026-07-04T00:00:00","isAllDay":true}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success")
        }
        XCTAssertTrue(preview.isAllDay)
    }

    func testCreateEventWithReminder() async {
        let json = #"{"action":"create","title":"Meeting","start":"2026-06-01T09:00:00","end":"2026-06-01T10:00:00","reminderMinutes":15}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success")
        }
        XCTAssertEqual(preview.reminderMinutes, 15)
        XCTAssertEqual(mock.createdEvents.count, 1)
    }

    func testCreateEventWithRecurrence() async {
        let json = #"{"action":"create","title":"Standup","start":"2026-06-02T09:00:00","end":"2026-06-02T09:30:00","recurrence":"weekly"}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success")
        }
        XCTAssertEqual(preview.recurrence, "weekly")
    }

    func testCreateMissingTitleFails() async {
        let json = #"{"action":"create","start":"2026-06-01T10:00:00","end":"2026-06-01T11:00:00"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for missing title")
        }
    }

    // MARK: - Delete

    func testDeleteBySearchTitle() async {
        mock.stubbedEvents = [makeEvent(title: "Dentist")]
        let json = #"{"action":"delete","search":"Dentist"}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success")
        }
        XCTAssertEqual(preview.state, .pendingDeletion)
        XCTAssertEqual(preview.title, "Dentist")
    }

    func testDeleteNotFoundFails() async {
        mock.stubbedEvents = []
        let json = #"{"action":"delete","search":"Nonexistent"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure when event not found")
        }
    }

    func testBulkDeleteByDateRange() async {
        mock.stubbedEvents = [
            makeEvent(title: "Event A"),
            makeEvent(title: "Event B"),
        ]
        let json = #"{"action":"delete","start":"2026-06-01T00:00:00","end":"2026-06-01T23:59:59"}"#
        let result = await controller.execute(json: json)
        guard case .bulkPending(let previews) = result else {
            return XCTFail("Expected .bulkPending")
        }
        XCTAssertEqual(previews.count, 2)
        XCTAssertTrue(previews.allSatisfy { $0.state == .pendingDeletion })
        XCTAssertTrue(previews.allSatisfy { !$0.title.isEmpty })
    }

    // MARK: - Update

    func testUpdateEventRename() async {
        mock.stubbedEvents = [makeEvent(title: "Team Sync")]
        let json = #"{"action":"update","search":"Team Sync","title":"Weekly Review"}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success")
        }
        XCTAssertEqual(preview.state, .pendingUpdate)
        XCTAssertEqual(preview.pendingUpdate?.title, "Weekly Review")
    }

    func testUpdateEventReschedule() async {
        mock.stubbedEvents = [makeEvent(title: "Dentist")]
        let json = #"{"action":"update","search":"Dentist","start":"2026-06-10T14:00:00","end":"2026-06-10T15:00:00"}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success")
        }
        guard let pendingStart = preview.pendingUpdate?.start else {
            return XCTFail("Expected pendingUpdate.start to be set")
        }
        XCTAssertEqual(Calendar.current.component(.hour, from: pendingStart), 14)
        XCTAssertEqual(Calendar.current.component(.minute, from: pendingStart), 0)
    }

    func testUpdateNoFieldsFails() async {
        mock.stubbedEvents = [makeEvent(title: "Meeting")]
        let json = #"{"action":"update","search":"Meeting"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure when no fields to update")
        }
    }

    // MARK: - Malformed input

    func testMalformedJSONFails() async {
        let result = await controller.execute(json: "{not valid json}")
        guard case .failure = result else {
            return XCTFail("Expected .failure for malformed JSON")
        }
    }

    func testEmptyJSONFails() async {
        let result = await controller.execute(json: "")
        guard case .failure = result else {
            return XCTFail("Expected .failure for empty input")
        }
    }

    // MARK: - Free slot query

    func testFreeSlotQueryNoEvents() async {
        mock.stubbedEvents = []
        let json = #"{"action":"query","start":"2026-06-01T08:00:00","end":"2026-06-01T20:00:00","durationMinutes":60}"#
        let result = await controller.execute(json: json)
        guard case .queryResult(let answer) = result else {
            return XCTFail("Expected .queryResult")
        }
        XCTAssertFalse(answer.isEmpty)
        XCTAssertTrue(answer.contains("Free") || answer.contains("slot") || answer.contains("•"))
    }

    func testFreeSlotQueryInvalidRangeFails() async {
        let json = #"{"action":"query","start":"2026-06-01T20:00:00","end":"2026-06-01T08:00:00","durationMinutes":60}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for inverted range")
        }
    }

    func testFreeSlotQueryZeroDurationFails() async {
        let json = #"{"action":"query","start":"2026-06-01T08:00:00","end":"2026-06-01T20:00:00","durationMinutes":0}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for zero duration")
        }
    }

    // MARK: - Create validation

    func testCreateMissingStartFails() async {
        let json = #"{"action":"create","title":"Meeting","end":"2026-06-01T11:00:00"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for missing start")
        }
    }

    func testCreateMissingEndFails() async {
        let json = #"{"action":"create","title":"Meeting","start":"2026-06-01T10:00:00"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for missing end")
        }
    }

    // MARK: - Update validation

    func testUpdateMissingSearchFails() async {
        let json = #"{"action":"update","title":"New Title"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure when search is missing")
        }
    }

    func testUpdateEventNotFoundFails() async {
        mock.stubbedEvents = []
        let json = #"{"action":"update","search":"Ghost Event","title":"New"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure when event not found")
        }
    }

    // MARK: - Delete validation

    func testDeleteMissingSearchAndRangeFails() async {
        let json = #"{"action":"delete"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure when neither search nor range provided")
        }
    }

    func testBulkDeleteNoEventsInRangeFails() async {
        mock.stubbedEvents = []
        let json = #"{"action":"delete","start":"2026-06-01T00:00:00","end":"2026-06-01T23:59:59"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure when no events in range")
        }
    }

    // MARK: - Query validation

    func testQueryMissingStartFails() async {
        let json = #"{"action":"query","end":"2026-06-01T20:00:00","durationMinutes":60}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for missing start")
        }
    }

    func testQueryWithEventsReturnsReducedSlots() async {
        // Busy all day → no free slots
        mock.stubbedEvents = [makeEvent(title: "All Day")]
        // Override event times to cover entire window
        let json = #"{"action":"query","start":"2026-06-01T08:00:00","end":"2026-06-01T09:00:00","durationMinutes":120}"#
        let result = await controller.execute(json: json)
        guard case .queryResult(let answer) = result else {
            return XCTFail("Expected .queryResult")
        }
        // Window is 1h but we need 2h — should report no slots
        XCTAssertTrue(answer.contains("No free"))
    }

    // MARK: - Helpers

    private func makeEvent(title: String) -> EKEvent {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = Date(timeIntervalSinceNow: 3600)
        event.endDate   = Date(timeIntervalSinceNow: 7200)
        return event
    }
}
