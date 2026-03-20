import XCTest
@testable import PocketMind

/// Verifies UserDefaultsKeys constants are correct and distinct — guards against
/// accidental key renames that would silently break persisted user preferences.
final class UserDefaultsKeysTests: XCTestCase {

    // MARK: - AppSettings keys

    func testCalendarAccessEnabledKey() {
        XCTAssertEqual(UserDefaultsKeys.calendarAccessEnabled, "calendarAccessEnabled")
    }

    func testSelectedModelIDKey() {
        XCTAssertEqual(UserDefaultsKeys.selectedModelID, "selectedModelID")
    }

    func testHasCompletedOnboardingKey() {
        XCTAssertEqual(UserDefaultsKeys.hasCompletedOnboarding, "hasCompletedOnboarding")
    }

    func testThinkingEnabledKey() {
        XCTAssertEqual(UserDefaultsKeys.thinkingEnabled, "thinkingEnabled")
    }

    func testDefaultCalendarIdentifierKey() {
        XCTAssertEqual(UserDefaultsKeys.defaultCalendarIdentifier, "defaultCalendarIdentifier")
    }

    func testSpeechAutoSendEnabledKey() {
        XCTAssertEqual(UserDefaultsKeys.speechAutoSendEnabled, "speechAutoSendEnabled")
    }

    // MARK: - Siri handoff keys

    func testSiriPendingQueryKey() {
        XCTAssertEqual(UserDefaultsKeys.siriPendingQuery, "pm_siri_pending_query")
    }

    func testSiriPendingEventKey() {
        XCTAssertEqual(UserDefaultsKeys.siriPendingEvent, "pm_siri_pending_event")
    }

    // MARK: - Suggestions cache keys

    func testSuggestionsCacheKey() {
        XCTAssertEqual(UserDefaultsKeys.suggestionsCache, "pm_suggestions")
    }

    func testSuggestionsCacheDateKey() {
        XCTAssertEqual(UserDefaultsKeys.suggestionsCacheDate, "pm_suggestions_date")
    }

    // MARK: - Uniqueness

    func testAllKeysAreUnique() {
        let keys = [
            UserDefaultsKeys.calendarAccessEnabled,
            UserDefaultsKeys.selectedModelID,
            UserDefaultsKeys.hasCompletedOnboarding,
            UserDefaultsKeys.thinkingEnabled,
            UserDefaultsKeys.defaultCalendarIdentifier,
            UserDefaultsKeys.speechAutoSendEnabled,
            UserDefaultsKeys.siriPendingQuery,
            UserDefaultsKeys.siriPendingEvent,
            UserDefaultsKeys.suggestionsCache,
            UserDefaultsKeys.suggestionsCacheDate,
        ]
        XCTAssertEqual(keys.count, Set(keys).count, "Duplicate UserDefaults key detected")
    }
}
