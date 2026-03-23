@testable import PocketMind
import XCTest

@MainActor
final class SiriPendingEventTests: XCTestCase {

    // MARK: - Identity

    func testEachInstanceHasUniqueID() {
        let date = Date(timeIntervalSinceNow: 3600)
        let a = SiriPendingEvent(title: "Meeting", date: date)
        let b = SiriPendingEvent(title: "Meeting", date: date)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testIDIsStableAcrossAccesses() {
        let event = SiriPendingEvent(title: "Dentist", date: .now)
        XCTAssertEqual(event.id, event.id)
    }

    // MARK: - Properties

    func testTitleIsPreserved() {
        let event = SiriPendingEvent(title: "Team Sync", date: .now)
        XCTAssertEqual(event.title, "Team Sync")
    }

    func testDateIsPreserved() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let event = SiriPendingEvent(title: "Lunch", date: date)
        XCTAssertEqual(event.date, date)
    }

    // MARK: - Codable round-trip

    func testEncodesAndDecodesTitle() throws {
        let original = SiriPendingEvent(title: "Sprint Planning", date: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SiriPendingEvent.self, from: data)
        XCTAssertEqual(decoded.title, original.title)
    }

    func testEncodesAndDecodesDate() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let original = SiriPendingEvent(title: "Retrospective", date: date)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SiriPendingEvent.self, from: data)
        XCTAssertEqual(decoded.date.timeIntervalSince1970, original.date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testEncodesAndDecodesID() throws {
        let original = SiriPendingEvent(title: "Standup", date: .now)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SiriPendingEvent.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
    }

    func testDecodedIDMatchesEncodedID() throws {
        let original = SiriPendingEvent(title: "Offsite", date: .now)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SiriPendingEvent.self, from: data)
        // Round-tripped ID must equal original — not a freshly generated one
        XCTAssertEqual(decoded.id, original.id)
    }

    func testInvalidJSONThrows() {
        let badData = Data("not json".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(SiriPendingEvent.self, from: badData))
    }

    func testMissingTitleFieldThrows() {
        let json = #"{"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","date":0}"#
        XCTAssertThrowsError(
            try JSONDecoder().decode(SiriPendingEvent.self, from: Data(json.utf8))
        )
    }
}
