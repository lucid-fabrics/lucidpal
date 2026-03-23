@testable import PocketMind
import XCTest

/// Tests for all 4 Siri intent types. Verifies that perform() writes the
/// correct query to UserDefaults and does not throw on valid input.
@MainActor
final class SiriIntentTests: XCTestCase {

    private let key = "pm_siri_pending_query"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - AskPocketMindIntent

    func testAskPocketMindIntentStoresQuery() async throws {
        var intent = AskPocketMindIntent()
        intent.query = "What meetings do I have tomorrow?"
        _ = try await intent.perform()
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "What meetings do I have tomorrow?")
    }

    func testAskPocketMindIntentTrimsWhitespace() async throws {
        var intent = AskPocketMindIntent()
        intent.query = "  What's on my calendar?  "
        _ = try await intent.perform()
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "What's on my calendar?")
    }

    func testAskPocketMindIntentThrowsOnEmptyQuery() async {
        var intent = AskPocketMindIntent()
        intent.query = "   "
        do {
            _ = try await intent.perform()
            XCTFail("Expected throw for empty query")
        } catch {
            XCTAssertTrue(error is SiriQueryError)
        }
    }

    // MARK: - CheckCalendarIntent

    func testCheckCalendarIntentStoresCalendarQuery() async throws {
        let intent = CheckCalendarIntent()
        _ = try await intent.perform()
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "What's on my calendar today?")
    }

    func testCheckCalendarIntentDoesNotThrow() async {
        let intent = CheckCalendarIntent()
        do {
            _ = try await intent.perform()
        } catch {
            XCTFail("CheckCalendarIntent should not throw: \(error)")
        }
    }

    // MARK: - AddCalendarEventIntent

    func testAddCalendarEventIntentFormatsQuery() async throws {
        var intent = AddCalendarEventIntent()
        intent.event = "dentist appointment"
        _ = try await intent.perform()
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "Add dentist appointment to my calendar")
    }

    func testAddCalendarEventIntentThrowsOnEmptyEvent() async {
        var intent = AddCalendarEventIntent()
        intent.event = "  "
        do {
            _ = try await intent.perform()
            XCTFail("Expected throw for empty event")
        } catch {
            XCTAssertTrue(error is SiriQueryError)
        }
    }

    // MARK: - FindFreeTimeIntent

    func testFindFreeTimeIntentStoresFreeSlotQuery() async throws {
        let intent = FindFreeTimeIntent()
        _ = try await intent.perform()
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "Find a free 1-hour slot today")
    }

    func testFindFreeTimeIntentDoesNotThrow() async {
        let intent = FindFreeTimeIntent()
        do {
            _ = try await intent.perform()
        } catch {
            XCTFail("FindFreeTimeIntent should not throw: \(error)")
        }
    }
}
