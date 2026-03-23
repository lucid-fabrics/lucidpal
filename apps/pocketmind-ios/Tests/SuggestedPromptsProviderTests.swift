@testable import PocketMind
import XCTest

@MainActor
final class SuggestedPromptsProviderTests: XCTestCase {

    // MARK: - Unauthorized calendar

    func testUnauthorizedCalendarReturnsExactlyFourPrompts() {
        let service = MockCalendarService()
        service.isAuthorized = false
        let sut = SuggestedPromptsProvider(calendarService: service)

        let prompts = sut.buildPrompts()

        XCTAssertEqual(prompts.count, 4)
    }

    func testUnauthorizedCalendarPromptsAreNonEmpty() {
        let service = MockCalendarService()
        service.isAuthorized = false
        let sut = SuggestedPromptsProvider(calendarService: service)

        let prompts = sut.buildPrompts()

        XCTAssertTrue(prompts.allSatisfy { !$0.isEmpty })
    }

    // MARK: - Authorized calendar, no events

    func testAuthorizedWithNoEventsReturnsExactlyFourPrompts() {
        let service = MockCalendarService()
        service.isAuthorized = true
        service.stubbedEvents = []
        let sut = SuggestedPromptsProvider(calendarService: service)

        let prompts = sut.buildPrompts()

        XCTAssertEqual(prompts.count, 4)
    }

    // MARK: - Always 4 prompts

    func testAlwaysReturnsFourPromptsRegardlessOfState() {
        let states: [(isAuthorized: Bool, hasEvents: Bool)] = [
            (false, false),
            (true, false),
            (true, true),
        ]

        for state in states {
            let service = MockCalendarService()
            service.isAuthorized = state.isAuthorized
            if state.hasEvents {
                service.stubbedEvents = [
                    CalendarEventInfo(
                        eventIdentifier: "e1",
                        title: "Stand-up",
                        startDate: Date(timeIntervalSinceNow: 1800),
                        endDate: Date(timeIntervalSinceNow: 3600),
                        isAllDay: false,
                        calendarTitle: "Work",
                        isRecurring: false
                    )
                ]
            }
            let sut = SuggestedPromptsProvider(calendarService: service)
            XCTAssertEqual(sut.buildPrompts().count, 4,
                           "Expected 4 prompts for authorized=\(state.isAuthorized) hasEvents=\(state.hasEvents)")
        }
    }

    func testNoPromptIsEmpty() {
        let service = MockCalendarService()
        service.isAuthorized = true
        let sut = SuggestedPromptsProvider(calendarService: service)

        let prompts = sut.buildPrompts()

        XCTAssertTrue(prompts.allSatisfy { !$0.isEmpty })
    }

    func testAllPromptsAreUnique() {
        let service = MockCalendarService()
        service.isAuthorized = true
        let sut = SuggestedPromptsProvider(calendarService: service)

        let prompts = sut.buildPrompts()

        XCTAssertEqual(prompts.count, Set(prompts).count)
    }
}
