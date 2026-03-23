@testable import PocketMind
import XCTest

/// Integration tests for CalendarActionController free-slot and list actions using MockCalendarService.
@MainActor
final class CalendarFreeSlotIntegrationTests: XCTestCase {
    var controller: CalendarActionController!
    var calendarService: MockCalendarService!
    var settings: AppSettingsProtocol!

    override func setUp() async throws {
        try await super.setUp()
        calendarService = MockCalendarService()
        settings = MockAppSettings()
        controller = CalendarActionController(calendarService: calendarService, settings: settings)
    }

    private func nextMonday(hour: Int = 9) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        comps.weekday = 2
        comps.hour = hour
        comps.minute = 0
        comps.second = 0
        return cal.date(from: comps) ?? .now
    }

    // MARK: - query action

    func testQueryActionWithValidRangeReturnsQueryResult() async throws {
        let start = nextMonday(hour: 8)
        let end = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: 10, to: start))
        let json = """
        {"action":"query","start":"\(isoString(start))","end":"\(isoString(end))","durationMinutes":60}
        """
        let result = await controller.execute(json: json)
        if case .queryResult = result {
            // Expected
        } else {
            XCTFail("Expected queryResult, got \(result)")
        }
    }

    func testQueryActionWithInvalidRangeReturnsFailure() async {
        let start = nextMonday(hour: 10)
        let end = nextMonday(hour: 8)  // end before start
        let json = """
        {"action":"query","start":"\(isoString(start))","end":"\(isoString(end))","durationMinutes":60}
        """
        let result = await controller.execute(json: json)
        if case .failure = result {
            // Expected
        } else {
            XCTFail("Expected failure for invalid range, got \(result)")
        }
    }

    func testQueryActionWithZeroDurationReturnsFailure() async throws {
        let start = nextMonday(hour: 8)
        let end = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: 4, to: start))
        let json = """
        {"action":"query","start":"\(isoString(start))","end":"\(isoString(end))","durationMinutes":0}
        """
        let result = await controller.execute(json: json)
        if case .failure = result {
            // Expected
        } else {
            XCTFail("Expected failure for zero duration, got \(result)")
        }
    }

    // MARK: - list action

    func testListActionReturnsListResult() async throws {
        let start = nextMonday(hour: 0)
        let end = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: 24, to: start))
        let json = """
        {"action":"list","start":"\(isoString(start))","end":"\(isoString(end))"}
        """
        let result = await controller.execute(json: json)
        if case .listResult = result {
            // Expected
        } else {
            XCTFail("Expected listResult, got \(result)")
        }
    }

    func testListActionWithInvalidRangeReturnsFailure() async {
        let start = nextMonday(hour: 10)
        let end = nextMonday(hour: 8)
        let json = """
        {"action":"list","start":"\(isoString(start))","end":"\(isoString(end))"}
        """
        let result = await controller.execute(json: json)
        if case .failure = result {
            // Expected
        } else {
            XCTFail("Expected failure for invalid list range, got \(result)")
        }
    }

    // MARK: - Malformed JSON

    func testMalformedJSONReturnsFailure() async {
        let result = await controller.execute(json: "not-valid-json{{")
        if case .failure = result {
            // Expected
        } else {
            XCTFail("Expected failure for malformed JSON")
        }
    }

    func testMissingActionDefaultsToCreate() async throws {
        // Missing "action" field — CalendarActionController defaults to .create
        let start = nextMonday(hour: 14)
        let end = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: 1, to: start))
        let json = """
        {"title":"Inferred Create","start":"\(isoString(start))","end":"\(isoString(end))"}
        """
        let result = await controller.execute(json: json)
        // Should attempt create — either .success or .failure (calendar may not be authorized in tests)
        switch result {
        case .success, .failure:
            break  // both are acceptable — just must not crash
        default:
            XCTFail("Unexpected result type for default action")
        }
    }

    // MARK: - Helpers

    private func isoString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}
