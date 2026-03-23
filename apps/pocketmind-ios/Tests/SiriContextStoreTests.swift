@testable import PocketMind
import XCTest

@MainActor
final class SiriContextStoreTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        SiriContextStore.clear()
    }

    override func tearDown() async throws {
        SiriContextStore.clear()
        try await super.tearDown()
    }

    // MARK: - Write / Read

    func testWriteThenRead() throws {
        let action = makeAction(type: .created, title: "Team Sync")

        SiriContextStore.write(action)
        let read = SiriContextStore.read()

        let result = try XCTUnwrap(read)
        XCTAssertEqual(result.eventTitle, "Team Sync")
        XCTAssertEqual(result.type, .created)
    }

    func testReadReturnsNilWhenNothingWritten() {
        // setUp already called clear()
        XCTAssertNil(SiriContextStore.read())
    }

    // MARK: - Clear

    func testClearRemovesStoredAction() {
        SiriContextStore.write(makeAction())

        SiriContextStore.clear()

        XCTAssertNil(SiriContextStore.read())
    }

    // MARK: - Overwrite

    func testWriteOverwritesPreviousAction() {
        SiriContextStore.write(makeAction(type: .created, title: "Event A"))
        SiriContextStore.write(makeAction(type: .deleted, title: "Event B"))

        let read = SiriContextStore.read()

        XCTAssertEqual(read?.eventTitle, "Event B")
        XCTAssertEqual(read?.type, .deleted)
    }

    // MARK: - Round-trip field fidelity

    func testRoundtripPreservesAllFields() {
        let action = makeAction(type: .updated, title: "Board Meeting")

        SiriContextStore.write(action)
        let read = SiriContextStore.read()

        XCTAssertEqual(read?.type, .updated)
        XCTAssertEqual(read?.eventTitle, "Board Meeting")
        XCTAssertEqual(read?.eventStart, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(read?.eventEnd, Date(timeIntervalSince1970: 1_700_003_600))
        XCTAssertEqual(read?.calendarName, "Work")
        XCTAssertEqual(read?.calendarIdentifier, "cal-123")
        XCTAssertEqual(read?.isAllDay, false)
        XCTAssertEqual(read?.location, "Room 1")
        XCTAssertEqual(read?.notes, "Test notes")
        XCTAssertEqual(read?.eventIdentifier, "evt-456")
        XCTAssertEqual(read?.timestamp, Date(timeIntervalSince1970: 1_700_000_000))
    }

    // MARK: - Helpers

    private func makeAction(
        type: SiriLastAction.ActionType = .created,
        title: String = "Test Event"
    ) -> SiriLastAction {
        SiriLastAction(
            type: type,
            eventTitle: title,
            eventStart: Date(timeIntervalSince1970: 1_700_000_000),
            eventEnd: Date(timeIntervalSince1970: 1_700_003_600),
            calendarName: "Work",
            calendarIdentifier: "cal-123",
            isAllDay: false,
            location: "Room 1",
            notes: "Test notes",
            eventIdentifier: "evt-456",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
