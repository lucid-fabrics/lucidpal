import XCTest
@testable import PocketMind

@MainActor
final class ChatViewModelPersistenceTests: XCTestCase {
    var llm: MockLLMService!
    var history: MockChatHistoryManager!
    var viewModel: ChatViewModel!

    override func setUp() {
        super.setUp()
        llm = MockLLMService()
        history = MockChatHistoryManager()
        viewModel = ChatViewModel(
            llmService: llm,
            calendarService: MockCalendarService(),
            settings: MockAppSettings(),
            systemPromptBuilder: MockSystemPromptBuilder(),
            suggestedPromptsProvider: MockSuggestedPromptsProvider(),
            speechService: MockSpeechService(),
            hapticService: MockHapticService(),
            historyManager: history
        )
    }

    // MARK: - clearHistory

    func testClearHistoryEmptiesMessages() {
        viewModel.messages = [ChatMessage(role: .user, content: "hello")]
        viewModel.clearHistory()
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testClearHistoryCancelsLLMGeneration() {
        viewModel.clearHistory()
        XCTAssertTrue(llm.cancelCalled)
    }

    func testClearHistoryCallsHistoryClear() {
        viewModel.clearHistory()
        XCTAssertTrue(history.clearCalled)
    }

    func testClearHistoryDoesNotSave() {
        viewModel.clearHistory()
        XCTAssertFalse(history.saveCalled)
    }

    // MARK: - flushPersistence

    func testFlushPersistenceSavesCurrentMessages() {
        let msg = ChatMessage(role: .user, content: "test")
        viewModel.messages = [msg]
        viewModel.flushPersistence()
        XCTAssertTrue(history.saveCalled)
        XCTAssertEqual(history.storedMessages.count, 1)
        XCTAssertEqual(history.storedMessages.first?.content, "test")
    }

    func testFlushPersistenceWithEmptyMessagesSavesEmpty() {
        viewModel.messages = []
        viewModel.flushPersistence()
        XCTAssertTrue(history.saveCalled)
        XCTAssertTrue(history.storedMessages.isEmpty)
    }

    func testFlushPersistencePreservesAllMessages() {
        viewModel.messages = [
            ChatMessage(role: .user, content: "one"),
            ChatMessage(role: .assistant, content: "two"),
            ChatMessage(role: .user, content: "three"),
        ]
        viewModel.flushPersistence()
        XCTAssertEqual(history.storedMessages.count, 3)
    }
}
