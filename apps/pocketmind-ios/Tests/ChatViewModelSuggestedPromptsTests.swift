import XCTest
@testable import PocketMind

@MainActor
final class ChatViewModelSuggestedPromptsTests: XCTestCase {
    var llm: MockLLMService!
    var viewModel: ChatViewModel!

    override func setUp() {
        super.setUp()
        llm = MockLLMService()
        viewModel = ChatViewModel(
            llmService: llm,
            calendarService: MockCalendarService(),
            calendarActionController: MockCalendarActionController(),
            settings: AppSettings(),
            speechService: MockSpeechService(),
            hapticService: MockHapticService(),
            historyManager: MockChatHistoryManager()
        )
    }

    // MARK: - Default state

    func testDefaultSuggestedPromptsHasFourEntries() {
        XCTAssertEqual(viewModel.suggestedPrompts.count, 4)
    }

    func testFallbackPromptsHasFourEntries() {
        XCTAssertEqual(ChatViewModel.fallbackPrompts.count, 4)
    }

    func testIsGeneratingSuggestionsStartsFalse() {
        XCTAssertFalse(viewModel.isGeneratingSuggestions)
    }

    func testSuggestionsTaskStartsNil() {
        XCTAssertNil(viewModel.suggestionsTask)
    }

    // MARK: - cancelSuggestionsGeneration

    func testCancelSuggestionsGenerationSetsFlagFalse() async {
        // Drive isGeneratingSuggestions to true by starting a slow LLM
        // then immediately cancel.
        llm.stubbedTokens = []
        viewModel.isGeneratingSuggestions = true
        viewModel.suggestionsTask = Task {}
        viewModel.cancelSuggestionsGeneration()
        XCTAssertFalse(viewModel.isGeneratingSuggestions)
    }

    func testCancelSuggestionsGenerationNilsTask() {
        viewModel.suggestionsTask = Task {}
        viewModel.cancelSuggestionsGeneration()
        XCTAssertNil(viewModel.suggestionsTask)
    }

    // MARK: - generateSuggestedPrompts — guard against double-invocation

    func testGenerateSuggestionsIsNoOpWhenAlreadyGenerating() async {
        viewModel.isGeneratingSuggestions = true
        // Even with tokens available, should not run because guard fires.
        llm.stubbedTokens = ["[\"A?\",\"B?\",\"C?\",\"D?\"]"]
        llm.isLoaded = true
        await viewModel.generateSuggestedPrompts()
        // Prompts should be unchanged (still the 4 defaults).
        XCTAssertEqual(viewModel.suggestedPrompts, ChatViewModel.fallbackPrompts)
    }

    // MARK: - generateSuggestedPrompts — LLM path

    func testGenerateSuggestionsPopulatesPromptsFromLLMOutput() async {
        // Clear UserDefaults cache so loadCachedSuggestions() returns nil.
        UserDefaults.standard.removeObject(forKey: "pm_suggestions_date")
        UserDefaults.standard.removeObject(forKey: "pm_suggestions")

        llm.isLoaded = true
        llm.stubbedTokens = ["[\"Q1?\",\"Q2?\",\"Q3?\",\"Q4?\"]"]
        await viewModel.generateSuggestedPrompts()
        XCTAssertEqual(viewModel.suggestedPrompts, ["Q1?", "Q2?", "Q3?", "Q4?"])
    }

    func testGenerateSuggestionsLeavesPromptsUnchangedOnLLMError() async {
        UserDefaults.standard.removeObject(forKey: "pm_suggestions_date")
        UserDefaults.standard.removeObject(forKey: "pm_suggestions")

        llm.isLoaded = true
        llm.shouldThrowOnGenerate = NSError(domain: "test", code: 1)
        let before = viewModel.suggestedPrompts
        await viewModel.generateSuggestedPrompts()
        XCTAssertEqual(viewModel.suggestedPrompts, before)
    }

    func testGenerateSuggestionsLeavesPromptsUnchangedOnMalformedJSON() async {
        UserDefaults.standard.removeObject(forKey: "pm_suggestions_date")
        UserDefaults.standard.removeObject(forKey: "pm_suggestions")

        llm.isLoaded = true
        llm.stubbedTokens = ["not json at all"]
        let before = viewModel.suggestedPrompts
        await viewModel.generateSuggestedPrompts()
        XCTAssertEqual(viewModel.suggestedPrompts, before)
    }

    func testGenerateSuggestionsSetsIsGeneratingFalseAfterCompletion() async {
        UserDefaults.standard.removeObject(forKey: "pm_suggestions_date")
        UserDefaults.standard.removeObject(forKey: "pm_suggestions")

        llm.isLoaded = true
        llm.stubbedTokens = ["[\"A?\",\"B?\",\"C?\",\"D?\"]"]
        await viewModel.generateSuggestedPrompts()
        XCTAssertFalse(viewModel.isGeneratingSuggestions)
    }

    // MARK: - Caching

    func testGenerateSuggestionsUsesCacheWhenDateIsToday() async {
        let prompts = ["Cached1?", "Cached2?", "Cached3?", "Cached4?"]
        let data = try! JSONEncoder().encode(prompts)
        UserDefaults.standard.set(data, forKey: "pm_suggestions")
        UserDefaults.standard.set(Date(), forKey: "pm_suggestions_date")

        llm.isLoaded = true
        llm.stubbedTokens = ["[\"New1?\",\"New2?\",\"New3?\",\"New4?\"]"]
        await viewModel.generateSuggestedPrompts()

        // Cache should win; LLM tokens should not be used.
        XCTAssertEqual(viewModel.suggestedPrompts, prompts)
    }

    func testGenerateSuggestionsIgnoresStaleCache() async {
        let prompts = ["Old1?", "Old2?", "Old3?", "Old4?"]
        let data = try! JSONEncoder().encode(prompts)
        UserDefaults.standard.set(data, forKey: "pm_suggestions")
        // Yesterday
        UserDefaults.standard.set(Date(timeIntervalSinceNow: -86_400), forKey: "pm_suggestions_date")

        llm.isLoaded = true
        llm.stubbedTokens = ["[\"Fresh1?\",\"Fresh2?\",\"Fresh3?\",\"Fresh4?\"]"]
        await viewModel.generateSuggestedPrompts()

        XCTAssertEqual(viewModel.suggestedPrompts, ["Fresh1?", "Fresh2?", "Fresh3?", "Fresh4?"])
    }

    // MARK: - Teardown (clean UserDefaults)

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "pm_suggestions")
        UserDefaults.standard.removeObject(forKey: "pm_suggestions_date")
        super.tearDown()
    }
}
