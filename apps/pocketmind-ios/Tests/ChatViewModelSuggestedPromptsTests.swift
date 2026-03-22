import XCTest
@testable import PocketMind

@MainActor
final class ChatViewModelSuggestedPromptsTests: XCTestCase {
    var calendar: MockCalendarService!
    var viewModel: ChatViewModel!

    override func setUp() {
        super.setUp()
        calendar = MockCalendarService()
        viewModel = ChatViewModel(
            llmService: MockLLMService(),
            calendarService: calendar,
            settings: MockAppSettings(),
            systemPromptBuilder: MockSystemPromptBuilder(),
            suggestedPromptsProvider: SuggestedPromptsProvider(calendarService: calendar),
            speechService: MockSpeechService(),
            hapticService: MockHapticService(),
            historyManager: MockChatHistoryManager()
        )
    }

    // MARK: - Default state

    func testDefaultSuggestedPromptsIsEmpty() {
        XCTAssertTrue(viewModel.suggestedPrompts.isEmpty)
    }

    func testIsGeneratingSuggestionsStartsFalse() {
        XCTAssertFalse(viewModel.isGeneratingSuggestions)
    }

    // MARK: - generateSuggestedPrompts — produces 4 prompts

    func testGenerateProducesFourPrompts() async {
        await viewModel.generateSuggestedPrompts()
        XCTAssertEqual(viewModel.suggestedPrompts.count, 4)
    }

    func testGenerateSetsIsGeneratingFalseAfterCompletion() async {
        await viewModel.generateSuggestedPrompts()
        XCTAssertFalse(viewModel.isGeneratingSuggestions)
    }

    // MARK: - Guard against double-invocation

    func testGenerateIsNoOpWhenAlreadyGenerating() async {
        viewModel.isGeneratingSuggestions = true
        await viewModel.generateSuggestedPrompts()
        XCTAssertTrue(viewModel.suggestedPrompts.isEmpty)
    }

    // MARK: - cancelSuggestionsGeneration

    func testCancelSetsFlagFalse() {
        viewModel.isGeneratingSuggestions = true
        viewModel.cancelSuggestionsGeneration()
        XCTAssertFalse(viewModel.isGeneratingSuggestions)
    }

    // MARK: - Calendar-aware content

    func testNoEventsShowsWeekQuestion() async {
        calendar.stubbedEvents = []
        await viewModel.generateSuggestedPrompts()
        XCTAssertTrue(viewModel.suggestedPrompts[0].contains("week"))
    }

    func testTodayEventsShowsTodayQuestion() async {
        calendar.stubbedEvents = [makeEvent(title: "Standup", hoursFromNow: 1)]
        await viewModel.generateSuggestedPrompts()
        XCTAssertTrue(viewModel.suggestedPrompts[0].contains("today"))
    }

    func testNextEventTitleAppearsInSecondPrompt() async {
        calendar.stubbedEvents = [makeEvent(title: "Team Sync", hoursFromNow: 2)]
        await viewModel.generateSuggestedPrompts()
        XCTAssertTrue(viewModel.suggestedPrompts[1].contains("Team Sync"))
    }

    func testNoCalendarAccessUsesGenericPrompts() async {
        calendar.isAuthorized = false
        await viewModel.generateSuggestedPrompts()
        XCTAssertEqual(viewModel.suggestedPrompts.count, 4)
        XCTAssertTrue(viewModel.suggestedPrompts[0].contains("calendar"))
    }

    func testFourthPromptMentionsFreeSlot() async {
        await viewModel.generateSuggestedPrompts()
        XCTAssertTrue(viewModel.suggestedPrompts[3].lowercased().contains("free"))
    }

    // MARK: - Helpers

    private func makeEvent(title: String, hoursFromNow: Double) -> CalendarEventInfo {
        let start = Date.now.addingTimeInterval(hoursFromNow * 3600)
        let end = start.addingTimeInterval(3600)
        return CalendarEventInfo(
            eventIdentifier: UUID().uuidString,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: false,
            calendarTitle: "Work"
        )
    }
}
