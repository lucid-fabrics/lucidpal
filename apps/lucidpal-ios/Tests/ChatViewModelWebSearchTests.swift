import XCTest

@testable import LucidPal

// MARK: - MockSystemPromptBuilderWithSearch

@MainActor
final class MockSystemPromptBuilderWithSearch: SystemPromptBuilderProtocol {
    var stubbedPrompt = "system"
    var executeCalendarActionsResult: (content: String, previews: [CalendarEventPreview], freeSlots: [CalendarFreeSlot]) = ("", [], [])
    var extractResult: (query: String, maxResults: Int)?

    func buildSystemPrompt() async -> String { stubbedPrompt }
    func buildSynthesisPrompt() async -> String { stubbedPrompt }

    func executeCalendarActions(in text: String) async -> (content: String, previews: [CalendarEventPreview], freeSlots: [CalendarFreeSlot]) {
        let r = executeCalendarActionsResult
        return (r.content.isEmpty ? text : r.content, r.previews, r.freeSlots)
    }

    func extractWebSearchQuery(from text: String) -> (query: String, maxResults: Int)? { extractResult }
}

// MARK: - ChatViewModelWebSearchTests

@MainActor
final class ChatViewModelWebSearchTests: XCTestCase {

    private var llm: MockLLMService!
    private var searchService: MockWebSearchService!
    private var promptBuilder: MockSystemPromptBuilderWithSearch!
    private var settings: MockAppSettings!
    private var viewModel: ChatViewModel!

    override func setUp() async throws {
        try await super.setUp()
        llm = MockLLMService()
        llm.isLoaded = true
        searchService = MockWebSearchService()
        promptBuilder = MockSystemPromptBuilderWithSearch()
        settings = MockAppSettings()
        settings.webSearchEnabled = true
        settings.webSearchEndpoint = "http://localhost:8888"

        viewModel = ChatViewModel(
            dependencies: ChatViewModelDependencies(
                llmService: llm,
                calendarService: MockCalendarService(),
                settings: settings,
                systemPromptBuilder: promptBuilder,
                suggestedPromptsProvider: MockSuggestedPromptsProvider(),
                speechService: MockSpeechService(),
                hapticService: MockHapticService(),
                historyManager: MockChatHistoryManager(),
                airPodsCoordinator: nil,
                webSearchService: searchService
            )
        )
    }

    // MARK: - Query extraction

    func testExtractWebSearchQueryNotCalledWhenDisabled() async throws {
        settings.webSearchEnabled = false
        llm.stubbedTokens = ["Hello"]
        promptBuilder.extractResult = nil

        viewModel.inputText = "What is the weather?"
        await viewModel.sendMessage()

        XCTAssertFalse(searchService.searchCalled)
    }

    func testNoSearchWhenExtractReturnsNil() async throws {
        llm.stubbedTokens = ["Direct answer"]
        promptBuilder.extractResult = nil

        viewModel.inputText = "Tell me something"
        await viewModel.sendMessage()

        XCTAssertFalse(searchService.searchCalled)
    }

    // MARK: - Agentic loop

    func testSearchIsCalledWhenQueryExtracted() async throws {
        // First LLM pass returns a search tag
        llm.stubbedTokens = ["[WEB_SEARCH:{\"query\":\"swift concurrency\"}]"]
        promptBuilder.extractResult = (query: "swift concurrency", maxResults: 5)
        searchService.stubbedResults = [
            WebSearchResult(title: "Swift Docs", url: "https://swift.org", snippet: "Concurrency model")
        ]
        // Second LLM pass returns final answer
        llm.secondStubbedTokens = ["Swift concurrency uses actors."]

        viewModel.inputText = "Explain Swift concurrency"
        await viewModel.sendMessage()

        XCTAssertTrue(searchService.searchCalled)
        XCTAssertEqual(searchService.lastQuery, "swift concurrency")
        XCTAssertEqual(searchService.lastMaxResults, 5)
    }

    func testFinalAssistantMessageContainsSearchSynthesis() async throws {
        llm.stubbedTokens = ["[WEB_SEARCH:{\"query\":\"test\"}]"]
        promptBuilder.extractResult = (query: "test", maxResults: 3)
        searchService.stubbedResults = [
            WebSearchResult(title: "Page A", url: "https://a.com", snippet: "Relevant info")
        ]
        llm.secondStubbedTokens = ["Synthesized answer from search."]

        viewModel.inputText = "Search for something"
        await viewModel.sendMessage()

        let lastAssistant = viewModel.messages.last(where: { $0.role == .assistant })
        XCTAssertEqual(lastAssistant?.content, "Synthesized answer from search.")
    }

    func testSearchErrorDoesNotCrashAndShowsFailureMessage() async throws {
        llm.stubbedTokens = ["[WEB_SEARCH:{\"query\":\"q\"}]"]
        promptBuilder.extractResult = (query: "q", maxResults: 5)
        searchService.stubbedError = URLError(.notConnectedToInternet)

        viewModel.inputText = "Search with error"
        await viewModel.sendMessage()

        let content = try XCTUnwrap(viewModel.messages.last(where: { $0.role == .assistant })?.content)
        XCTAssertTrue(content.hasPrefix("Search failed:"))
    }

    func testSearchNotCalledWhenEndpointEmpty() async throws {
        settings.webSearchEndpoint = ""
        llm.stubbedTokens = ["[WEB_SEARCH:{\"query\":\"q\"}]"]
        promptBuilder.extractResult = (query: "q", maxResults: 5)

        viewModel.inputText = "Search something"
        await viewModel.sendMessage()

        XCTAssertFalse(searchService.searchCalled)
    }

    func testEmptySearchResultsStillProducesAssistantMessage() async throws {
        llm.stubbedTokens = ["[WEB_SEARCH:{\"query\":\"q\"}]"]
        promptBuilder.extractResult = (query: "q", maxResults: 5)
        searchService.stubbedResults = []
        llm.secondStubbedTokens = ["No results found for your query."]

        viewModel.inputText = "Search for something obscure"
        await viewModel.sendMessage()

        let lastAssistant = viewModel.messages.last(where: { $0.role == .assistant })
        XCTAssertEqual(lastAssistant?.content, "No results found for your query.")
    }

    func testSearchSucceedsButSynthesisProducesEmptyContent() async throws {
        // Search returns results but LLM synthesis streams a single empty token.
        // The assistant message must exist with empty string content, not be absent.
        llm.stubbedTokens = ["[WEB_SEARCH:{\"query\":\"q\"}]"]
        promptBuilder.extractResult = (query: "q", maxResults: 3)
        searchService.stubbedResults = [
            WebSearchResult(title: "Page", url: "https://example.com", snippet: "Info")
        ]
        llm.secondStubbedTokens = [""]  // LLM synthesis produces empty token

        viewModel.inputText = "Search something"
        await viewModel.sendMessage()

        let lastAssistant = try XCTUnwrap(viewModel.messages.last(where: { $0.role == .assistant }))
        XCTAssertEqual(lastAssistant.content, "", "Empty synthesis token should yield empty string content")
    }
}
