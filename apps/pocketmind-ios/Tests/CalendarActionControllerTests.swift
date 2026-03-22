import XCTest
@testable import PocketMind

@MainActor
final class CalendarActionControllerTests: XCTestCase {
    var mock: MockCalendarService!
    var settings: AppSettingsProtocol!
    var controller: CalendarActionController!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockCalendarService()
        settings = MockAppSettings()
        controller = CalendarActionController(calendarService: mock, settings: settings)
    }

    // MARK: - Create

    func testCreateEventSuccess() async throws {
        let json = #"{"action":"create","title":"Dentist","start":"2026-06-01T10:00:00","end":"2026-06-01T11:00:00"}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success, got \(result)")
        }
        XCTAssertEqual(preview.title, "Dentist")
        XCTAssertEqual(preview.state, .created)
        XCTAssertEqual(mock.createdEvents.count, 1)
    }

    func testCreateEventAllDay() async throws {
        let json = #"{"action":"create","title":"Holiday","start":"2026-07-04T00:00:00","end":"2026-07-04T00:00:00","isAllDay":true}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success")
        }
        XCTAssertTrue(preview.isAllDay)
        XCTAssertEqual(mock.createdEvents.first?.isAllDay, true)
        XCTAssertEqual(mock.createdEvents.first?.title, "Holiday")
    }

    func testCreateEventWithReminder() async throws {
        let json = #"{"action":"create","title":"Meeting","start":"2026-06-01T09:00:00","end":"2026-06-01T10:00:00","reminderMinutes":15}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success")
        }
        XCTAssertEqual(preview.reminderMinutes, 15)
        XCTAssertEqual(mock.createdEvents.count, 1)
    }

    func testCreateEventWithRecurrence() async throws {
        let json = #"{"action":"create","title":"Standup","start":"2026-06-02T09:00:00","end":"2026-06-02T09:30:00","recurrence":"weekly"}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success")
        }
        XCTAssertEqual(preview.recurrence, "weekly")
    }

    func testCreateMissingTitleFails() async throws {
        let json = #"{"action":"create","start":"2026-06-01T10:00:00","end":"2026-06-01T11:00:00"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for missing title")
        }
    }

    // MARK: - Delete

    func testDeleteBySearchTitle() async throws {
        mock.stubbedEvents = [makeEvent(title: "Dentist")]
        let json = #"{"action":"delete","search":"Dentist"}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success")
        }
        XCTAssertEqual(preview.state, .pendingDeletion)
        XCTAssertEqual(preview.title, "Dentist")
    }

    func testDeleteNotFoundFails() async throws {
        mock.stubbedEvents = []
        let json = #"{"action":"delete","search":"Nonexistent"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure when event not found")
        }
    }

    func testBulkDeleteByDateRange() async throws {
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
        XCTAssertEqual(previews.map(\.state), [.pendingDeletion, .pendingDeletion])
        XCTAssertEqual(previews.map(\.title).sorted(), ["Event A", "Event B"])
    }

    // MARK: - Update

    func testUpdateEventRename() async throws {
        mock.stubbedEvents = [makeEvent(title: "Team Sync")]
        let json = #"{"action":"update","search":"Team Sync","title":"Weekly Review"}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success")
        }
        XCTAssertEqual(preview.state, .pendingUpdate)
        XCTAssertEqual(preview.pendingUpdate?.title, "Weekly Review")
    }

    func testUpdateEventReschedule() async throws {
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

    func testUpdateNoFieldsFails() async throws {
        mock.stubbedEvents = [makeEvent(title: "Meeting")]
        let json = #"{"action":"update","search":"Meeting"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure when no fields to update")
        }
    }

    // MARK: - Malformed input

    func testMalformedJSONFails() async throws {
        let result = await controller.execute(json: "{not valid json}")
        guard case .failure = result else {
            return XCTFail("Expected .failure for malformed JSON")
        }
    }

    func testEmptyJSONFails() async throws {
        let result = await controller.execute(json: "")
        guard case .failure = result else {
            return XCTFail("Expected .failure for empty input")
        }
    }

    // MARK: - Free slot query

    func testFreeSlotQueryNoEvents() async throws {
        mock.stubbedEvents = []
        let json = #"{"action":"query","start":"2026-06-01T08:00:00","end":"2026-06-01T20:00:00","durationMinutes":60}"#
        let result = await controller.execute(json: json)
        guard case .queryResult(let slots) = result else {
            return XCTFail("Expected .queryResult")
        }
        XCTAssertFalse(slots.isEmpty)
    }

    func testFreeSlotQueryInvalidRangeFails() async throws {
        let json = #"{"action":"query","start":"2026-06-01T20:00:00","end":"2026-06-01T08:00:00","durationMinutes":60}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for inverted range")
        }
    }

    func testFreeSlotQueryZeroDurationFails() async throws {
        let json = #"{"action":"query","start":"2026-06-01T08:00:00","end":"2026-06-01T20:00:00","durationMinutes":0}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for zero duration")
        }
    }

    // MARK: - Create validation

    func testCreateMissingStartFails() async throws {
        let json = #"{"action":"create","title":"Meeting","end":"2026-06-01T11:00:00"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for missing start")
        }
    }

    func testCreateMissingEndFails() async throws {
        let json = #"{"action":"create","title":"Meeting","start":"2026-06-01T10:00:00"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for missing end")
        }
    }

    // MARK: - Update validation

    func testUpdateMissingSearchFails() async throws {
        let json = #"{"action":"update","title":"New Title"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure when search is missing")
        }
    }

    func testUpdateEventNotFoundFails() async throws {
        mock.stubbedEvents = []
        let json = #"{"action":"update","search":"Ghost Event","title":"New"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure when event not found")
        }
    }

    // MARK: - Delete validation

    func testDeleteMissingSearchAndRangeFails() async throws {
        let json = #"{"action":"delete"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure when neither search nor range provided")
        }
    }

    func testBulkDeleteNoEventsInRangeFails() async throws {
        mock.stubbedEvents = []
        let json = #"{"action":"delete","start":"2026-06-01T00:00:00","end":"2026-06-01T23:59:59"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure when no events in range")
        }
    }

    // MARK: - Query validation

    func testQueryMissingStartFails() async throws {
        let json = #"{"action":"query","end":"2026-06-01T20:00:00","durationMinutes":60}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for missing start")
        }
    }

    func testQueryWithEventsReturnsReducedSlots() async throws {
        // Window is 1h but we need 2h — no free slots regardless of events
        let json = #"{"action":"query","start":"2026-06-01T08:00:00","end":"2026-06-01T09:00:00","durationMinutes":120}"#
        let result = await controller.execute(json: json)
        guard case .queryResult(let slots) = result else {
            return XCTFail("Expected .queryResult")
        }
        // Window is 1h but we need 2h — should return no slots
        XCTAssertTrue(slots.isEmpty)
    }

    // MARK: - Date edge cases

    func testCreateInvalidDateStringReturnsFailed() async throws {
        let json = #"{"action":"create","title":"Test","start":"not-a-date","end":"also-not-a-date"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for invalid date strings, got \(result)")
        }
    }

    func testCreateExtremeYearSucceeds() async throws {
        let json = #"{"action":"create","title":"FarFuture","start":"2099-12-31T23:00:00","end":"2099-12-31T23:59:00"}"#
        let result = await controller.execute(json: json)
        guard case .success(_, let preview) = result else {
            return XCTFail("Expected .success for extreme future date, got \(result)")
        }
        XCTAssertEqual(preview.title, "FarFuture")
    }

    // MARK: - Malformed JSON

    func testEmptyJsonStringReturnsFailed() async throws {
        let result = await controller.execute(json: "")
        guard case .failure = result else {
            return XCTFail("Expected .failure for empty JSON string")
        }
    }

    func testMalformedJsonSyntaxReturnsFailed() async throws {
        let result = await controller.execute(json: "{not valid json{{")
        guard case .failure = result else {
            return XCTFail("Expected .failure for malformed JSON syntax")
        }
    }

    func testUnknownActionReturnsFailed() async throws {
        let json = #"{"action":"teleport","title":"Beam me up"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure for unknown action type")
        }
    }

    func testMissingActionKeyReturnsFailed() async throws {
        let json = #"{"title":"Meeting","start":"2026-06-01T10:00:00","end":"2026-06-01T11:00:00"}"#
        let result = await controller.execute(json: json)
        guard case .failure = result else {
            return XCTFail("Expected .failure when action key is missing")
        }
    }

    // MARK: - Helpers

    private func makeEvent(title: String) -> CalendarEventInfo {
        CalendarEventInfo(
            eventIdentifier: "mock-\(title)",
            title: title,
            startDate: Date(timeIntervalSinceNow: 3600),
            endDate: Date(timeIntervalSinceNow: 7200),
            isAllDay: false,
            calendarTitle: "Test Calendar"
        )
    }
}
