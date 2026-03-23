@testable import PocketMind
import XCTest

@MainActor
final class ChatViewModelEdgeCaseTests: XCTestCase {
    var llm: MockLLMService!
    var calendarService: MockCalendarService!
    var settings: AppSettingsProtocol!
    var viewModel: ChatViewModel!

    override func setUp() async throws {
        try await super.setUp()
        llm = MockLLMService()
        calendarService = MockCalendarService()
        settings = MockAppSettings()
        viewModel = ChatViewModel(
            dependencies: ChatViewModelDependencies(
                llmService: llm,
                calendarService: calendarService,
                settings: settings,
                systemPromptBuilder: MockSystemPromptBuilder(),
                suggestedPromptsProvider: MockSuggestedPromptsProvider(),
                speechService: MockSpeechService(),
                hapticService: MockHapticService(),
                historyManager: MockChatHistoryManager(),
                airPodsCoordinator: nil,
                webSearchService: nil
            )
        )
    }

    // MARK: - Guard conditions

    func testSendMessageDoesNothingWhenInputEmpty() async {
        llm.isLoaded = true
        viewModel.inputText = "   "
        await viewModel.sendMessage()
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testSendMessageDoesNothingWhenModelNotLoaded() async {
        llm.isLoaded = false
        viewModel.inputText = "Hello"
        await viewModel.sendMessage()
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testSendMessageDoesNothingWhenAlreadyGenerating() async {
        llm.isLoaded = true
        llm.isGenerating = true
        viewModel.inputText = "Hello"
        await viewModel.sendMessage()
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    // MARK: - Input clearing

    func testSendMessageClearsInputText() async {
        llm.isLoaded = true
        llm.stubbedTokens = ["Hello!"]
        viewModel.inputText = "Test"
        await viewModel.sendMessage()
        XCTAssertEqual(viewModel.inputText, "")
    }

    // MARK: - Session title auto-derivation

    func testSessionTitleRemainsUnchangedWhenNoSessionManager() async {
        llm.isLoaded = true
        llm.stubbedTokens = []
        viewModel.inputText = "Tell me about Swift"
        let titleBefore = viewModel.sessionTitle
        await viewModel.sendMessage()
        XCTAssertEqual(viewModel.sessionTitle, titleBefore)
    }

    // MARK: - deleteMessage

    func testDeleteMessageRemovesCorrectMessage() async throws {
        let msg1 = ChatMessage(role: .user, content: "First")
        let msg2 = ChatMessage(role: .user, content: "Second")
        viewModel.messages = [msg1, msg2]
        viewModel.deleteMessage(id: msg1.id)
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.content, "Second")
    }

    func testDeleteMessageWithUnknownIDIsNoOp() async throws {
        viewModel.messages = [ChatMessage(role: .user, content: "A")]
        viewModel.deleteMessage(id: UUID())
        XCTAssertEqual(viewModel.messages.count, 1)
    }

    // MARK: - clearHistory

    func testClearHistoryEmptiesMessages() async throws {
        viewModel.messages = [
            ChatMessage(role: .user, content: "A"),
            ChatMessage(role: .assistant, content: "B")
        ]
        viewModel.clearHistory()
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    // MARK: - applyStreamToken edge cases

    func testApplyStreamTokenWithNoThinkTag() async throws {
        var raw = ""
        var thinkDone = false
        viewModel.messages = [ChatMessage(role: .assistant, content: "")]
        viewModel.applyStreamToken("Hello", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: 0)
        XCTAssertTrue(thinkDone)
        XCTAssertEqual(viewModel.messages[0].content, "Hello")
    }

    func testApplyStreamTokenBuffersOpeningTag() async throws {
        var raw = ""
        var thinkDone = false
        viewModel.messages = [ChatMessage(role: .assistant, content: "")]
        viewModel.applyStreamToken("<thi", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: 0)
        XCTAssertFalse(thinkDone)
        XCTAssertEqual(viewModel.messages[0].content, "")
    }

    func testApplyStreamTokenExtractsThinkingContent() async throws {
        var raw = ""
        var thinkDone = false
        viewModel.messages = [ChatMessage(role: .assistant, content: "")]
        let fullToken = "<think>reasoning here</think>\nAnswer"
        viewModel.applyStreamToken(fullToken, rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: 0)
        XCTAssertTrue(thinkDone)
        XCTAssertEqual(viewModel.messages[0].thinkingContent, "reasoning here")
        XCTAssertEqual(viewModel.messages[0].content, "Answer")
    }

    // MARK: - needsDateSeparator

    func testNeedsDateSeparatorAtIndexZeroAlwaysReturnsTrue() {
        viewModel.messages = [ChatMessage(role: .user, content: "Hello")]
        XCTAssertTrue(viewModel.needsDateSeparator(at: 0))
    }

    func testNeedsDateSeparatorSameDayReturnsFalse() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let msg1 = ChatMessage(role: .user, content: "First", timestamp: base)
        let msg2 = ChatMessage(role: .assistant, content: "Second", timestamp: base.addingTimeInterval(3600))
        viewModel.messages = [msg1, msg2]
        XCTAssertFalse(viewModel.needsDateSeparator(at: 1))
    }

    func testNeedsDateSeparatorDifferentDayReturnsTrue() {
        let day1 = Date(timeIntervalSinceReferenceDate: 0)
        let day2 = day1.addingTimeInterval(86400)
        let msg1 = ChatMessage(role: .user, content: "Yesterday", timestamp: day1)
        let msg2 = ChatMessage(role: .assistant, content: "Today", timestamp: day2)
        viewModel.messages = [msg1, msg2]
        XCTAssertTrue(viewModel.needsDateSeparator(at: 1))
    }
}
