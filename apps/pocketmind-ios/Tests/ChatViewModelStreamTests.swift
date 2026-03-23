@testable import PocketMind
import XCTest

@MainActor
final class ChatViewModelStreamTests: XCTestCase {
    var viewModel: ChatViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ChatViewModel(
            dependencies: ChatViewModelDependencies(
                llmService: MockLLMService(),
                calendarService: MockCalendarService(),
                settings: MockAppSettings(),
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

    private func appendAssistantMessage() -> Int {
        viewModel.messages.append(ChatMessage(role: .assistant, content: ""))
        return viewModel.messages.count - 1
    }

    // MARK: - CalendarAction regex

    func testDisplayContentHandlesNestedBracesInJSON() {
        let content = #"[CALENDAR_ACTION:{"action":"create","notes":"Room {A}"}]Done."#
        let msg = ChatMessage(role: .assistant, content: content)
        XCTAssertEqual(msg.displayContent, "Done.")
    }

    func testDisplayContentHandlesMultipleActionBlocks() {
        let content = "[CALENDAR_ACTION:{\"action\":\"delete\",\"search\":\"A\"}]\n[CALENDAR_ACTION:{\"action\":\"create\",\"title\":\"B\"}]\nAll done."
        let msg = ChatMessage(role: .assistant, content: content)
        XCTAssertEqual(msg.displayContent, "All done.")
    }

    // MARK: - applyStreamToken

    func testApplyStreamTokenAfterThinkDoneAppendsDirectly() {
        let idx = appendAssistantMessage()
        viewModel.messages[idx].content = "hello"
        var raw = "hello"
        var thinkDone = true
        viewModel.applyStreamToken(" world", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertEqual(viewModel.messages[idx].content, "hello world")
        XCTAssertTrue(thinkDone)
    }

    func testApplyStreamTokenCompletesThinkBlock() {
        let idx = appendAssistantMessage()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<think>reasoning</think>response", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        XCTAssertTrue(thinkDone)
        XCTAssertFalse(viewModel.messages[idx].isThinking)
        XCTAssertEqual(viewModel.messages[idx].thinkingContent, "reasoning")
        XCTAssertEqual(viewModel.messages[idx].content, "response")
    }

    func testApplyStreamTokenInsideThinkBlockSetsIsThinking() {
        let idx = appendAssistantMessage()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<think>partial", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        XCTAssertFalse(thinkDone)
        XCTAssertTrue(viewModel.messages[idx].isThinking)
        XCTAssertEqual(viewModel.messages[idx].thinkingContent, "partial")
    }

    func testApplyStreamTokenInsideThinkBlockHiddenWhenShowThinkingFalse() {
        let idx = appendAssistantMessage()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<think>partial", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertFalse(thinkDone)
        XCTAssertFalse(viewModel.messages[idx].isThinking)
        XCTAssertNil(viewModel.messages[idx].thinkingContent)
    }

    func testApplyStreamTokenBuffersPartialOpenTag() {
        let idx = appendAssistantMessage()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<thi", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertFalse(thinkDone)
        XCTAssertTrue(viewModel.messages[idx].content.isEmpty)
    }

    func testApplyStreamTokenNonThinkTokenSetsContentDirectly() {
        let idx = appendAssistantMessage()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("Hello", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertTrue(thinkDone)
        XCTAssertEqual(viewModel.messages[idx].content, "Hello")
    }

    func testApplyStreamTokenThinkBlockWithNoResponseTrimsWhitespace() {
        let idx = appendAssistantMessage()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<think>thinking</think>  ", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertTrue(thinkDone)
        XCTAssertTrue(viewModel.messages[idx].content.isEmpty)
    }

    // MARK: - Stream interruption

    func testCancellationLeavesPartialContentVisible() async throws {
        let llm = MockLLMService()
        llm.isLoaded = true
        llm.stubbedTokens = ["Partial"]
        llm.shouldThrowOnGenerate = CancellationError()
        let vm = ChatViewModel(
            dependencies: ChatViewModelDependencies(
                llmService: llm,
                calendarService: MockCalendarService(),
                settings: MockAppSettings(),
                systemPromptBuilder: MockSystemPromptBuilder(),
                suggestedPromptsProvider: MockSuggestedPromptsProvider(),
                speechService: MockSpeechService(),
                hapticService: MockHapticService(),
                historyManager: MockChatHistoryManager(),
                airPodsCoordinator: nil,
                webSearchService: nil
            )
        )

        vm.inputText = "Test cancellation"
        await vm.sendMessage()

        // Message slot must exist with partial content preserved, not cleared
        let assistantMsg = vm.messages.last(where: { $0.role == .assistant })
        XCTAssertEqual(assistantMsg?.content, "Partial")
    }
}
