import XCTest
@testable import PocketMind

@MainActor
final class ChatViewModelSendMessageTests: XCTestCase {
    var mock: MockCalendarService!
    var settings: AppSettingsProtocol!
    var viewModel: ChatViewModel!
    var llm: MockLLMService!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockCalendarService()
        settings = MockAppSettings()
        llm = MockLLMService()
        viewModel = ChatViewModel(
            llmService: llm,
            calendarService: mock,
            settings: settings,
            systemPromptBuilder: MockSystemPromptBuilder(),
            suggestedPromptsProvider: MockSuggestedPromptsProvider(),
            speechService: MockSpeechService(),
            hapticService: MockHapticService(),
            historyManager: MockChatHistoryManager()
        )
    }

    private func makeLoadedViewModel(tokens: [String] = []) -> (ChatViewModel, MockLLMService, MockSpeechService) {
        let mockLLM = MockLLMService()
        mockLLM.isLoaded = true
        mockLLM.stubbedTokens = tokens
        let speech = MockSpeechService()
        let vm = ChatViewModel(
            llmService: mockLLM,
            calendarService: mock,
            settings: settings,
            systemPromptBuilder: MockSystemPromptBuilder(),
            suggestedPromptsProvider: MockSuggestedPromptsProvider(),
            speechService: speech,
            hapticService: MockHapticService(),
            historyManager: MockChatHistoryManager()
        )
        return (vm, mockLLM, speech)
    }

    // MARK: - cancelGeneration / handleSiriQuery

    func testCancelGenerationCallsLLMService() {
        viewModel.cancelGeneration()
        XCTAssertTrue(llm.cancelCalled)
    }

    func testHandleSiriQuerySetsInputText() {
        viewModel.handleSiriQuery("What's on my calendar?")
        XCTAssertEqual(viewModel.inputText, "What's on my calendar?")
    }

    // MARK: - sendMessage

    func testSendMessageAppendsUserAndAssistantMessages() async throws {
        let (vm, _, _) = makeLoadedViewModel(tokens: ["Hello", " world"])
        vm.inputText = "hi"
        await vm.sendMessage()
        XCTAssertEqual(vm.messages.count, 2)
        XCTAssertEqual(vm.messages[0].role, .user)
        XCTAssertEqual(vm.messages[0].content, "hi")
        XCTAssertEqual(vm.messages[1].role, .assistant)
        XCTAssertEqual(vm.messages[1].content, "Hello world")
    }

    func testSendMessageClearsInputText() async throws {
        let (vm, _, _) = makeLoadedViewModel(tokens: ["ok"])
        vm.inputText = "test"
        await vm.sendMessage()
        XCTAssertEqual(vm.inputText, "")
    }

    func testSendMessageDoesNothingWhenModelNotLoaded() async throws {
        viewModel.inputText = "test"
        await viewModel.sendMessage()
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testSendMessageDoesNothingForEmptyInput() async throws {
        let (vm, _, _) = makeLoadedViewModel()
        vm.inputText = "   "
        await vm.sendMessage()
        XCTAssertTrue(vm.messages.isEmpty)
    }

    func testSendMessageSetsErrorOnLLMFailure() async throws {
        let (vm, mockLLM, _) = makeLoadedViewModel()
        mockLLM.shouldThrowOnGenerate = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "model error"])
        vm.inputText = "hi"
        await vm.sendMessage()
        let msg = try XCTUnwrap(vm.errorMessage)
        XCTAssertTrue(msg.contains("model error"))
    }

    func testSendMessageEmptyTokenStreamLeavesBlankAssistantMessage() async throws {
        let (vm, _, _) = makeLoadedViewModel(tokens: [])
        vm.inputText = "hi"
        await vm.sendMessage()
        XCTAssertEqual(vm.messages.count, 2)
        XCTAssertEqual(vm.messages[1].role, .assistant)
        XCTAssertTrue(vm.messages[1].content.isEmpty)
    }

    func testSendMessageWithWhitespaceOnlyInputIsNoOp() async throws {
        let (vm, _, _) = makeLoadedViewModel(tokens: ["hi"])
        vm.inputText = "   "
        await vm.sendMessage()
        XCTAssertTrue(vm.messages.isEmpty)
    }

    // MARK: - toggleSpeech

    func testToggleSpeechStartsRecordingWhenNotRecording() {
        let (vm, _, speech) = makeLoadedViewModel()
        speech.isAuthorized = true
        vm.toggleSpeech()
        XCTAssertTrue(speech.startCalled)
    }

    func testToggleSpeechStopsRecordingWhenAlreadyRecording() {
        let (vm, _, speech) = makeLoadedViewModel()
        speech.isRecording = true
        vm.toggleSpeech()
        XCTAssertTrue(speech.stopCalled)
    }

    func testToggleSpeechSetsErrorMessageOnStartFailure() throws {
        let (vm, _, speech) = makeLoadedViewModel()
        speech.shouldThrowOnStart = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "mic error"])
        vm.toggleSpeech()
        let msg = try XCTUnwrap(vm.errorMessage)
        XCTAssertTrue(msg.contains("mic error"))
    }

    // MARK: - Concurrency

    func testSendMessageIsNoOpWhileAlreadyGenerating() async throws {
        let (vm, mockLLM, _) = makeLoadedViewModel(tokens: ["hi"])
        mockLLM.isGenerating = true
        vm.inputText = "second"
        await vm.sendMessage()
        XCTAssertTrue(vm.messages.isEmpty)
    }

    // MARK: - clearHistory

    func testClearHistoryDuringGenerationCancelsLLM() {
        let (vm, mockLLM, _) = makeLoadedViewModel(tokens: ["a", "b"])
        mockLLM.isGenerating = true
        vm.clearHistory()
        XCTAssertTrue(vm.messages.isEmpty)
        XCTAssertTrue(mockLLM.cancelCalled)
    }

    // MARK: - deleteMessage

    func testDeleteMessageRemovesItFromMessages() {
        let msg = ChatMessage(role: .assistant, content: "to delete")
        viewModel.messages = [msg]
        viewModel.deleteMessage(id: msg.id)
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testDeleteMessageWithWrongIDIsNoOp() {
        let msg = ChatMessage(role: .assistant, content: "keep")
        viewModel.messages = [msg]
        viewModel.deleteMessage(id: UUID())
        XCTAssertEqual(viewModel.messages.count, 1)
    }
}
