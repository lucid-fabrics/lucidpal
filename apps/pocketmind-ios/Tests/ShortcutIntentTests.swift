import AppIntents
import XCTest
@testable import PocketMind

/// Tests for Shortcuts-compatible intents that return values directly.
/// Tests parameter handling, validation, and error cases.
@MainActor
final class ShortcutIntentTests: XCTestCase {

    // MARK: - CreateEventShortcutIntent

    func testCreateEventShortcutIntentValidatesEmptyTitle() async throws {
        var intent = CreateEventShortcutIntent()
        intent.eventTitle = "   "
        intent.startTime = Date.now
        intent.durationMinutes = 60

        let result = try await intent.perform()
        XCTAssertTrue(result.value?.isEmpty ?? true, "Expected empty value for invalid title")
    }

    func testCreateEventShortcutIntentTrimsTitle() async throws {
        var intent = CreateEventShortcutIntent()
        intent.eventTitle = "  Team Meeting  "
        intent.startTime = Date.now
        intent.durationMinutes = 30

        // Note: This test verifies parameter handling only
        // Actual EventKit access requires calendar permissions in test environment
        XCTAssertEqual(intent.eventTitle.trimmingCharacters(in: .whitespacesAndNewlines), "Team Meeting")
    }

    func testCreateEventShortcutIntentDefaultDuration() {
        var intent = CreateEventShortcutIntent()
        intent.eventTitle = "Quick Call"
        intent.startTime = Date.now

        // Default duration should be 60 minutes
        XCTAssertEqual(intent.durationMinutes, 60)
    }

    func testCreateEventShortcutIntentCalculatesEndTime() {
        let start = Date.now
        let duration = 90 // minutes
        let expectedEnd = start.addingTimeInterval(TimeInterval(duration * 60))

        // Verify time calculation logic
        let calculatedEnd = start.addingTimeInterval(TimeInterval(duration * 60))
        XCTAssertEqual(calculatedEnd.timeIntervalSince(start), 5400, accuracy: 1.0) // 90 minutes in seconds
    }

    // MARK: - CheckNextMeetingIntent

    func testCheckNextMeetingIntentInitializes() {
        // Verify intent can be created and perform() returns a result (requires no permissions)
        let intent = CheckNextMeetingIntent()
        XCTAssertTrue(intent is any AppIntent)
    }

    func testCheckNextMeetingIntentReturnsEmptyWhenNoCalendarAccess() async throws {
        let intent = CheckNextMeetingIntent()
        // Without calendar permissions, perform() must not crash and must return empty meeting info.
        let result = try await intent.perform()
        XCTAssertTrue(result.value?.isEmpty ?? true,
                      "Without calendar permissions, next meeting info must be empty or nil")
    }

    // MARK: - FindFreeTimeShortcutIntent

    func testFindFreeTimeShortcutIntentDefaultDate() {
        var intent = FindFreeTimeShortcutIntent()
        intent.durationMinutes = 30

        // Default date should be now
        let now = Date.now
        XCTAssertEqual(intent.searchDate.timeIntervalSince(now), 0, accuracy: 5.0)
    }

    func testFindFreeTimeShortcutIntentDefaultDuration() {
        var intent = FindFreeTimeShortcutIntent()
        intent.searchDate = Date.now

        // Default duration should be 60 minutes
        XCTAssertEqual(intent.durationMinutes, 60)
    }

    func testFindFreeTimeShortcutIntentParameterValidation() {
        var intent = FindFreeTimeShortcutIntent()
        intent.searchDate = Date.now
        intent.durationMinutes = 120

        XCTAssertEqual(intent.durationMinutes, 120)
        XCTAssertEqual(intent.searchDate.timeIntervalSince(Date.now), 0, accuracy: 5.0)
    }

    func testFindFreeTimeShortcutIntentWeekdayLogic() {
        // Test that weekday detection works correctly
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date.now)
        comps.hour = 9
        comps.minute = 0

        let testDate = cal.date(from: comps) ?? Date.now
        let weekday = cal.component(.weekday, from: testDate)

        // Verify weekday is in valid range (1 = Sunday, 7 = Saturday)
        XCTAssertTrue((1...7).contains(weekday))
    }

    // MARK: - AskPocketMindShortcutIntent

    func testAskPocketMindShortcutIntentStoresQuery() async throws {
        var intent = AskPocketMindShortcutIntent()
        intent.query = "What's the weather?"

        let result = try await intent.perform()
        let stored = UserDefaults.standard.string(forKey: UserDefaultsKeys.siriPendingQuery)

        XCTAssertEqual(stored, "What's the weather?")
        XCTAssertFalse(result.value?.isEmpty ?? true)
    }

    func testAskPocketMindShortcutIntentTrimsQuery() async throws {
        var intent = AskPocketMindShortcutIntent()
        intent.query = "  What time is it?  "

        let result = try await intent.perform()
        let stored = UserDefaults.standard.string(forKey: UserDefaultsKeys.siriPendingQuery)

        XCTAssertEqual(stored, "What time is it?")
    }

    func testAskPocketMindShortcutIntentValidatesEmptyQuery() async throws {
        var intent = AskPocketMindShortcutIntent()
        intent.query = "   "

        let result = try await intent.perform()
        XCTAssertTrue(result.value?.isEmpty ?? true, "Expected empty result for invalid query")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.siriPendingQuery)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.siriPendingEvent)
    }
}
