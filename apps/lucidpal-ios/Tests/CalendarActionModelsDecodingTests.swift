import XCTest

@testable import LucidPal

final class CalendarActionModelsDecodingTests: XCTestCase {

    // The same decoder the controller uses — replicate its date strategy.
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)

            let formats = [
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm",
            ]
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: raw) { return date }
            }

            let iso = ISO8601DateFormatter()
            for opt: ISO8601DateFormatter.Options in [
                [.withInternetDateTime],
                [.withInternetDateTime, .withFractionalSeconds],
                [.withFullDate, .withTime, .withColonSeparatorInTime],
            ] {
                iso.formatOptions = opt
                if let date = iso.date(from: raw) { return date }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date: \(raw)"
            )
        }
        return d
    }()

    // MARK: - Missing optional fields

    func testDecodeMinimalPayload() throws {
        let json = #"{"title":"Lunch"}"#
        let payload = try Self.decoder.decode(CalendarActionPayload.self, from: Data(json.utf8))
        XCTAssertNil(payload.action)
        XCTAssertEqual(payload.title, "Lunch")
        XCTAssertNil(payload.start)
        XCTAssertNil(payload.end)
        XCTAssertNil(payload.location)
        XCTAssertNil(payload.notes)
        XCTAssertNil(payload.reminderMinutes)
        XCTAssertNil(payload.isAllDay)
        XCTAssertNil(payload.recurrence)
        XCTAssertNil(payload.recurrenceEnd)
        XCTAssertNil(payload.durationMinutes)
        XCTAssertNil(payload.search)
    }

    func testDecodeEmptyObject() throws {
        let json = #"{}"#
        let payload = try Self.decoder.decode(CalendarActionPayload.self, from: Data(json.utf8))
        XCTAssertNil(payload.action)
        XCTAssertNil(payload.title)
    }

    // MARK: - Nil action defaults

    func testNilActionWhenOmitted() throws {
        let json = #"{"title":"Meeting"}"#
        let payload = try Self.decoder.decode(CalendarActionPayload.self, from: Data(json.utf8))
        XCTAssertNil(payload.action, "Omitted action should decode as nil (caller defaults to .create)")
    }

    func testExplicitNullAction() throws {
        let json = #"{"action":null,"title":"Meeting"}"#
        let payload = try Self.decoder.decode(CalendarActionPayload.self, from: Data(json.utf8))
        XCTAssertNil(payload.action)
    }

    // MARK: - Malformed date strings

    func testMalformedDateThrows() {
        let json = #"{"action":"create","title":"X","start":"not-a-date"}"#
        XCTAssertThrowsError(
            try Self.decoder.decode(CalendarActionPayload.self, from: Data(json.utf8))
        ) { error in
            guard case DecodingError.dataCorrupted = error else {
                return XCTFail("Expected dataCorrupted, got \(error)")
            }
        }
    }

    func testPartialDateThrows() {
        let json = #"{"action":"create","title":"X","start":"2026-06"}"#
        XCTAssertThrowsError(
            try Self.decoder.decode(CalendarActionPayload.self, from: Data(json.utf8))
        )
    }

    // MARK: - Valid date parsing

    func testValidISODate() throws {
        let json = #"{"action":"create","title":"X","start":"2026-06-01T10:00:00"}"#
        let payload = try Self.decoder.decode(CalendarActionPayload.self, from: Data(json.utf8))
        XCTAssertNotNil(payload.start)
    }

    // MARK: - All action types

    func testAllActionTypes() throws {
        for type in ["create", "update", "delete", "query", "list"] {
            let json = #"{"action":"\#(type)"}"#
            let payload = try Self.decoder.decode(CalendarActionPayload.self, from: Data(json.utf8))
            XCTAssertEqual(payload.action?.rawValue, type)
        }
    }

    func testInvalidActionTypeThrows() {
        let json = #"{"action":"unknown"}"#
        XCTAssertThrowsError(
            try Self.decoder.decode(CalendarActionPayload.self, from: Data(json.utf8))
        )
    }

    // MARK: - CalendarActionResult enum cases

    func testResultSuccessCase() {
        let preview = CalendarEventPreview(title: "Test", start: Date(), end: Date(), calendarName: nil, state: .created)
        let result = CalendarActionResult.success("Created", preview)
        if case .success(let msg, let p) = result {
            XCTAssertEqual(msg, "Created")
            XCTAssertEqual(p.title, "Test")
        } else {
            XCTFail("Expected .success")
        }
    }

    func testResultFailureCase() {
        let result = CalendarActionResult.failure("Bad input")
        if case .failure(let msg) = result {
            XCTAssertEqual(msg, "Bad input")
        } else {
            XCTFail("Expected .failure")
        }
    }

    func testResultBulkPendingCase() {
        let previews = [
            CalendarEventPreview(title: "A", start: Date(), end: Date(), calendarName: nil, state: .pendingDeletion),
            CalendarEventPreview(title: "B", start: Date(), end: Date(), calendarName: nil, state: .pendingDeletion),
        ]
        let result = CalendarActionResult.bulkPending(previews)
        if case .bulkPending(let items) = result {
            XCTAssertEqual(items.count, 2)
        } else {
            XCTFail("Expected .bulkPending")
        }
    }

    func testResultListResultCase() {
        let result = CalendarActionResult.listResult([])
        if case .listResult(let items) = result {
            XCTAssertTrue(items.isEmpty)
        } else {
            XCTFail("Expected .listResult")
        }
    }

    func testResultQueryResultCase() {
        let result = CalendarActionResult.queryResult([])
        if case .queryResult(let slots) = result {
            XCTAssertTrue(slots.isEmpty)
        } else {
            XCTFail("Expected .queryResult")
        }
    }
}
