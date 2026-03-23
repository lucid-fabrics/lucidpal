@testable import PocketMind
import XCTest

@MainActor
final class ChatViewModelMessageHandlingTests: XCTestCase {
    var llm: MockLLMService!
    var viewModel: ChatViewModel!

    override func setUp() {
        super.setUp()
        llm = MockLLMService()
        viewModel = ChatViewModel(
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
    }

    // MARK: - Helpers

    /// Appends a blank assistant message and returns its index.
    private func appendAssistant() -> Int {
        viewModel.messages.append(ChatMessage(role: .assistant, content: ""))
        return viewModel.messages.count - 1
    }

    // MARK: - showToast

    func testShowToastSetsToastItem() {
        viewModel.showToast("Event created", systemImage: "checkmark.circle")
        XCTAssertEqual(viewModel.toast?.message, "Event created")
        XCTAssertEqual(viewModel.toast?.systemImage, "checkmark.circle")
    }

    func testShowToastOverwritesPreviousToast() {
        viewModel.showToast("First", systemImage: "star")
        viewModel.showToast("Second", systemImage: "heart")
        XCTAssertEqual(viewModel.toast?.message, "Second")
    }

    // MARK: - applyStreamToken: thinkDone = true (direct append)

    func testApplyStreamTokenThinkDoneAppendsToken() {
        let idx = appendAssistant()
        viewModel.messages[idx].content = "Hello"
        var raw = "Hello"
        var thinkDone = true
        viewModel.applyStreamToken(" there", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertEqual(viewModel.messages[idx].content, "Hello there")
        XCTAssertTrue(thinkDone)
    }

    func testApplyStreamTokenThinkDoneUpdatesRawBuffer() {
        let idx = appendAssistant()
        var raw = "prefix"
        var thinkDone = true
        viewModel.applyStreamToken("X", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertEqual(raw, "prefixX")
    }

    // MARK: - applyStreamToken: plain token (no think tag)

    func testApplyStreamTokenPlainTokenSetsContentAndMarksDone() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("Sure!", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertTrue(thinkDone)
        XCTAssertEqual(viewModel.messages[idx].content, "Sure!")
    }

    func testApplyStreamTokenPlainTokenDoesNotSetIsThinking() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("response", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        XCTAssertFalse(viewModel.messages[idx].isThinking)
    }

    // MARK: - applyStreamToken: partial opening tag buffering

    func testApplyStreamTokenPartialTagLeavesContentEmpty() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<t", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertFalse(thinkDone)
        XCTAssertTrue(viewModel.messages[idx].content.isEmpty)
    }

    func testApplyStreamTokenPartialTagDoesNotSetIsThinking() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<thi", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        XCTAssertFalse(viewModel.messages[idx].isThinking)
    }

    func testApplyStreamTokenFullOpenTagWithoutCloseShowsThinkingContent() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<think>step one", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        XCTAssertFalse(thinkDone)
        XCTAssertTrue(viewModel.messages[idx].isThinking)
        XCTAssertEqual(viewModel.messages[idx].thinkingContent, "step one")
    }

    func testApplyStreamTokenFullOpenTagHiddenWhenShowThinkingFalse() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<think>step one", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertFalse(thinkDone)
        XCTAssertFalse(viewModel.messages[idx].isThinking)
    }

    // MARK: - applyStreamToken: complete <think>...</think> block

    func testApplyStreamTokenCompletedThinkBlockExtractsThinkingContent() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<think>my reasoning</think>final answer", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        XCTAssertTrue(thinkDone)
        XCTAssertEqual(viewModel.messages[idx].thinkingContent, "my reasoning")
        XCTAssertEqual(viewModel.messages[idx].content, "final answer")
        XCTAssertFalse(viewModel.messages[idx].isThinking)
    }

    func testApplyStreamTokenCompletedThinkBlockIgnoresThinkingContentWhenHidden() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<think>hidden</think>visible", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertTrue(thinkDone)
        XCTAssertNil(viewModel.messages[idx].thinkingContent)
        XCTAssertEqual(viewModel.messages[idx].content, "visible")
    }

    func testApplyStreamTokenCompletedThinkBlockTrimsWhitespaceFromResponse() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<think>r</think>   trimmed   ", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertEqual(viewModel.messages[idx].content, "trimmed")
    }

    func testApplyStreamTokenEmptyResponseAfterThinkBlock() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<think>thinking only</think>", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertTrue(thinkDone)
        XCTAssertTrue(viewModel.messages[idx].content.isEmpty)
    }

    func testApplyStreamTokenThinkBlockSetsIsThinkingFalse() {
        let idx = appendAssistant()
        viewModel.messages[idx].isThinking = true
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<think>x</think>done", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        XCTAssertFalse(viewModel.messages[idx].isThinking)
    }

    // MARK: - applyStreamToken: incremental multi-call simulation

    func testApplyStreamTokenIncrementalThinkThenResponse() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false

        // Token 1: opening tag + partial think body
        viewModel.applyStreamToken("<think>partial", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        XCTAssertFalse(thinkDone)

        // Token 2: rest of think + close tag + response
        viewModel.applyStreamToken(" thought</think>response text", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        XCTAssertTrue(thinkDone)
        XCTAssertEqual(viewModel.messages[idx].content, "response text")
    }

    func testApplyStreamTokenMultipleTokensAfterThinkDone() {
        let idx = appendAssistant()
        var raw = "Hello"
        var thinkDone = true
        viewModel.messages[idx].content = "Hello"

        viewModel.applyStreamToken(" World", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        viewModel.applyStreamToken("!", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)

        XCTAssertEqual(viewModel.messages[idx].content, "Hello World!")
    }

    // MARK: - applyStreamToken: empty token

    func testApplyStreamTokenEmptyTokenDoesNotCrash() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false
        // Should not crash or mutate state in a broken way
        viewModel.applyStreamToken("", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertFalse(thinkDone)
        XCTAssertTrue(viewModel.messages[idx].content.isEmpty)
    }

    func testApplyStreamTokenEmptyTokenWhenThinkDoneDoesNotCrash() {
        let idx = appendAssistant()
        viewModel.messages[idx].content = "existing"
        var raw = "existing"
        var thinkDone = true
        viewModel.applyStreamToken("", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        // Content unchanged when appending empty string
        XCTAssertEqual(viewModel.messages[idx].content, "existing")
        XCTAssertTrue(thinkDone)
    }

    // MARK: - applyStreamToken: thinkingContent trimming

    func testApplyStreamTokenThinkingContentIsTrimmed() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<think>  whitespace  </think>answer", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        XCTAssertEqual(viewModel.messages[idx].thinkingContent, "whitespace")
    }

    func testApplyStreamTokenIncrementalThinkingContentUpdatesEachToken() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false

        viewModel.applyStreamToken("<think>first", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        XCTAssertEqual(viewModel.messages[idx].thinkingContent, "first")

        viewModel.applyStreamToken(" second", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        XCTAssertEqual(viewModel.messages[idx].thinkingContent, "first second")
        XCTAssertFalse(thinkDone)
    }

    // MARK: - applyStreamToken: leading whitespace after </think>

    func testApplyStreamTokenLeadingWhitespaceAfterCloseTagIsTrimmed() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false
        viewModel.applyStreamToken("<think>r</think>\n\n  answer", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        XCTAssertEqual(viewModel.messages[idx].content, "answer")
    }

    // MARK: - applyStreamToken: rawBuffer accumulation

    func testApplyStreamTokenRawBufferAccumulatesAcrossIncrementalTokens() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = false

        viewModel.applyStreamToken("<think>", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        viewModel.applyStreamToken("thought", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)
        viewModel.applyStreamToken("</think>", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: true, idx: idx)

        XCTAssertEqual(raw, "<think>thought</think>")
        XCTAssertTrue(thinkDone)
        XCTAssertEqual(viewModel.messages[idx].thinkingContent, "thought")
        XCTAssertTrue(viewModel.messages[idx].content.isEmpty)
    }

    func testApplyStreamTokenRawBufferAccumulatesWhenThinkDone() {
        let idx = appendAssistant()
        var raw = ""
        var thinkDone = true

        viewModel.applyStreamToken("A", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)
        viewModel.applyStreamToken("B", rawBuffer: &raw, thinkDone: &thinkDone, showThinking: false, idx: idx)

        XCTAssertEqual(raw, "AB")
    }
}
