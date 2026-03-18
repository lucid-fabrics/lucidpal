import XCTest
@testable import PocketMind

@MainActor
final class ChatViewModelTests: XCTestCase {
    var mock: MockCalendarService!
    var settings: AppSettings!
    var controller: MockCalendarActionController!
    var llm: MockLLMService!
    var viewModel: ChatViewModel!

    override func setUp() {
        super.setUp()
        mock = MockCalendarService()
        settings = AppSettings()
        controller = MockCalendarActionController()
        llm = MockLLMService()
        viewModel = ChatViewModel(
            llmService: llm,
            calendarService: mock,
            calendarActionController: controller,
            settings: settings,
            speechService: MockSpeechService(),
            historyManager: MockChatHistoryManager()
        )
    }

    // MARK: - Helpers

    /// Inserts an assistant message with a single calendar preview and returns (messageID, previewID).
    private func insertMessage(state: CalendarEventPreview.PreviewState,
                               eventIdentifier: String? = "evt-1",
                               pendingUpdate: PendingCalendarUpdate? = nil) -> (msgID: UUID, previewID: UUID) {
        var preview = CalendarEventPreview(
            title: "Test Event",
            start: Date(timeIntervalSinceNow: 3600),
            end: Date(timeIntervalSinceNow: 7200),
            calendarName: "Work",
            state: state,
            eventIdentifier: eventIdentifier
        )
        preview.pendingUpdate = pendingUpdate
        var msg = ChatMessage(role: .assistant, content: "")
        msg.calendarEventPreviews = [preview]
        viewModel.messages.append(msg)
        return (msg.id, preview.id)
    }

    // MARK: - Deletion

    func testConfirmDeletionSetsStateToDeleted() async {
        let (msgID, previewID) = insertMessage(state: .pendingDeletion)
        await viewModel.confirmDeletion(messageID: msgID, previewID: previewID)
        let state = viewModel.messages.first?.calendarEventPreviews.first?.state
        XCTAssertEqual(state, .deleted)
        XCTAssertEqual(mock.deletedIdentifiers, ["evt-1"])
    }

    func testConfirmDeletionWithNilIdentifierIsNoOp() async {
        let (msgID, previewID) = insertMessage(state: .pendingDeletion, eventIdentifier: nil)
        await viewModel.confirmDeletion(messageID: msgID, previewID: previewID)
        let state = viewModel.messages.first?.calendarEventPreviews.first?.state
        XCTAssertEqual(state, .pendingDeletion)
        XCTAssertTrue(mock.deletedIdentifiers.isEmpty)
    }

    func testCancelDeletionSetsStateToCancelled() {
        let (msgID, previewID) = insertMessage(state: .pendingDeletion)
        viewModel.cancelDeletion(messageID: msgID, previewID: previewID)
        let state = viewModel.messages.first?.calendarEventPreviews.first?.state
        XCTAssertEqual(state, .deletionCancelled)
        XCTAssertTrue(mock.deletedIdentifiers.isEmpty)
    }

    func testUndoDeletionSetsStateToRestored() async {
        let (msgID, previewID) = insertMessage(state: .deleted)
        await viewModel.undoDeletion(messageID: msgID, previewID: previewID)
        let state = viewModel.messages.first?.calendarEventPreviews.first?.state
        XCTAssertEqual(state, .restored)
        XCTAssertEqual(mock.createdEvents.count, 1)
        XCTAssertEqual(mock.createdEvents.first?.title, "Test Event")
    }

    func testConfirmAllDeletionsSetsAllToDeleted() async {
        var preview1 = CalendarEventPreview(
            title: "A", start: .now, end: .now, calendarName: nil,
            state: .pendingDeletion, eventIdentifier: "id-1"
        )
        var preview2 = CalendarEventPreview(
            title: "B", start: .now, end: .now, calendarName: nil,
            state: .pendingDeletion, eventIdentifier: "id-2"
        )
        var msg = ChatMessage(role: .assistant, content: "")
        msg.calendarEventPreviews = [preview1, preview2]
        viewModel.messages.append(msg)

        await viewModel.confirmAllDeletions(messageID: msg.id)

        let states = viewModel.messages.first?.calendarEventPreviews.map(\.state)
        XCTAssertEqual(states, [.deleted, .deleted])
        XCTAssertEqual(Set(mock.deletedIdentifiers), ["id-1", "id-2"])
    }

    func testConfirmAllDeletionsPartialFailureSetsErrorMessage() async throws {
        mock.shouldThrowOnDelete = true
        let (msgID, _) = insertMessage(state: .pendingDeletion)
        await viewModel.confirmAllDeletions(messageID: msgID)
        let state = viewModel.messages.first?.calendarEventPreviews.first?.state
        XCTAssertEqual(state, .deletionCancelled)
        let errorMsg = try XCTUnwrap(viewModel.errorMessage)
        XCTAssertFalse(errorMsg.isEmpty)
    }

    func testCancelAllDeletionsSetsAllToCancelled() {
        var preview1 = CalendarEventPreview(
            title: "A", start: .now, end: .now, calendarName: nil,
            state: .pendingDeletion, eventIdentifier: "id-1"
        )
        var preview2 = CalendarEventPreview(
            title: "B", start: .now, end: .now, calendarName: nil,
            state: .pendingDeletion, eventIdentifier: "id-2"
        )
        var msg = ChatMessage(role: .assistant, content: "")
        msg.calendarEventPreviews = [preview1, preview2]
        viewModel.messages.append(msg)

        viewModel.cancelAllDeletions(messageID: msg.id)

        let states = viewModel.messages.first?.calendarEventPreviews.map(\.state)
        XCTAssertEqual(states, [.deletionCancelled, .deletionCancelled])
    }

    // MARK: - Update

    func testConfirmUpdateMirrorsFieldsAndClearsPending() async {
        var pending = PendingCalendarUpdate()
        pending.title = "Renamed"
        pending.start = Date(timeIntervalSinceNow: 7200)
        pending.end   = Date(timeIntervalSinceNow: 10800)
        let (msgID, previewID) = insertMessage(state: .pendingUpdate, pendingUpdate: pending)

        await viewModel.confirmUpdate(messageID: msgID, previewID: previewID)

        let preview = viewModel.messages.first?.calendarEventPreviews.first
        XCTAssertEqual(preview?.title, "Renamed")
        XCTAssertEqual(preview?.start, pending.start)
        XCTAssertNil(preview?.pendingUpdate)
        XCTAssertEqual(mock.appliedUpdates.count, 1)
    }

    func testConfirmUpdateSetsTerminalState() async {
        var pending = PendingCalendarUpdate()
        pending.title = "Renamed"
        let (msgID, previewID) = insertMessage(state: .pendingUpdate, pendingUpdate: pending)

        await viewModel.confirmUpdate(messageID: msgID, previewID: previewID)

        let state = viewModel.messages.first?.calendarEventPreviews.first?.state
        XCTAssertTrue(state == .updated || state == .rescheduled,
                      "Expected .updated or .rescheduled, got \(String(describing: state))")
    }

    func testConfirmUpdateEventNotFoundSetsErrorMessage() async throws {
        mock.shouldThrowOnApplyUpdate = true
        var pending = PendingCalendarUpdate()
        pending.title = "Oops"
        let (msgID, previewID) = insertMessage(state: .pendingUpdate, pendingUpdate: pending)

        await viewModel.confirmUpdate(messageID: msgID, previewID: previewID)

        let state = viewModel.messages.first?.calendarEventPreviews.first?.state
        XCTAssertEqual(state, .updateCancelled)
        let errorMsg = try XCTUnwrap(viewModel.errorMessage)
        XCTAssertFalse(errorMsg.isEmpty)
    }

    func testCancelUpdateSetsStateToCancelledAndClearsPending() {
        var pending = PendingCalendarUpdate()
        pending.title = "Should not apply"
        let (msgID, previewID) = insertMessage(state: .pendingUpdate, pendingUpdate: pending)

        viewModel.cancelUpdate(messageID: msgID, previewID: previewID)

        let preview = viewModel.messages.first?.calendarEventPreviews.first
        XCTAssertEqual(preview?.state, .updateCancelled)
        XCTAssertNil(preview?.pendingUpdate)
        XCTAssertTrue(mock.appliedUpdates.isEmpty)
    }

    // MARK: - History

    func testClearHistoryEmptiesMessages() {
        viewModel.messages = [
            ChatMessage(role: .user, content: "hello"),
            ChatMessage(role: .assistant, content: "hi"),
        ]
        viewModel.clearHistory()
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    // MARK: - Confirm deletion edge cases

    func testConfirmDeletionWithWrongMessageIDIsNoOp() async {
        let (_, previewID) = insertMessage(state: .pendingDeletion)
        await viewModel.confirmDeletion(messageID: UUID(), previewID: previewID)
        XCTAssertTrue(mock.deletedIdentifiers.isEmpty)
    }

    func testConfirmDeletionWithWrongPreviewIDIsNoOp() async {
        let (msgID, _) = insertMessage(state: .pendingDeletion)
        await viewModel.confirmDeletion(messageID: msgID, previewID: UUID())
        XCTAssertTrue(mock.deletedIdentifiers.isEmpty)
    }

    // MARK: - Update edge cases

    func testConfirmUpdateWithNoPendingUpdateIsNoOp() async {
        let (msgID, previewID) = insertMessage(state: .pendingUpdate, pendingUpdate: nil)
        await viewModel.confirmUpdate(messageID: msgID, previewID: previewID)
        XCTAssertTrue(mock.appliedUpdates.isEmpty)
    }

    func testCancelUpdateWithWrongIDsIsNoOp() {
        let (msgID, _) = insertMessage(state: .pendingUpdate)
        let before = viewModel.messages.first?.calendarEventPreviews.first?.state
        viewModel.cancelUpdate(messageID: msgID, previewID: UUID())
        let after = viewModel.messages.first?.calendarEventPreviews.first?.state
        XCTAssertEqual(before, after)
    }

    // MARK: - Bulk deletion edge cases

    func testConfirmAllDeletionsOnEmptyMessageIsNoOp() async {
        let msg = ChatMessage(role: .assistant, content: "no previews")
        viewModel.messages.append(msg)
        await viewModel.confirmAllDeletions(messageID: msg.id)
        XCTAssertTrue(mock.deletedIdentifiers.isEmpty)
    }

    func testCancelDeletionDoesNotAffectAlreadyDeletedPreviews() {
        var preview1 = CalendarEventPreview(title: "A", start: .now, end: .now, calendarName: nil, state: .deleted, eventIdentifier: "id-1")
        var preview2 = CalendarEventPreview(title: "B", start: .now, end: .now, calendarName: nil, state: .pendingDeletion, eventIdentifier: "id-2")
        var msg = ChatMessage(role: .assistant, content: "")
        msg.calendarEventPreviews = [preview1, preview2]
        viewModel.messages.append(msg)
        viewModel.cancelAllDeletions(messageID: msg.id)
        XCTAssertEqual(viewModel.messages.first?.calendarEventPreviews[0].state, .deleted)
        XCTAssertEqual(viewModel.messages.first?.calendarEventPreviews[1].state, .deletionCancelled)
    }

    // MARK: - flushPersistence / cancelGeneration / handleSiriQuery

    func testFlushPersistenceSavesMessages() {
        let history = MockChatHistoryManager()
        let vm = ChatViewModel(
            llmService: llm, calendarService: mock,
            calendarActionController: controller, settings: settings,
            speechService: MockSpeechService(), historyManager: history
        )
        vm.messages = [ChatMessage(role: .user, content: "test")]
        vm.flushPersistence()
        XCTAssertTrue(history.saveCalled)
    }

    func testCancelGenerationCallsLLMService() {
        viewModel.cancelGeneration()
        XCTAssertTrue(llm.cancelCalled)
    }

    func testHandleSiriQuerySetsInputText() {
        viewModel.handleSiriQuery("What's on my calendar?")
        XCTAssertEqual(viewModel.inputText, "What's on my calendar?")
    }

    // MARK: - sendMessage

    private func makeLoadedViewModel(tokens: [String] = []) -> (ChatViewModel, MockLLMService, MockSpeechService) {
        let llm = MockLLMService()
        llm.isLoaded = true
        llm.stubbedTokens = tokens
        let speech = MockSpeechService()
        let vm = ChatViewModel(
            llmService: llm,
            calendarService: mock,
            calendarActionController: MockCalendarActionController(),
            settings: settings,
            speechService: speech,
            historyManager: MockChatHistoryManager()
        )
        return (vm, llm, speech)
    }

    func testSendMessageAppendsUserAndAssistantMessages() async {
        let (vm, _, _) = makeLoadedViewModel(tokens: ["Hello", " world"])
        vm.inputText = "hi"
        await vm.sendMessage()
        XCTAssertEqual(vm.messages.count, 2)
        XCTAssertEqual(vm.messages[0].role, .user)
        XCTAssertEqual(vm.messages[0].content, "hi")
        XCTAssertEqual(vm.messages[1].role, .assistant)
        XCTAssertEqual(vm.messages[1].content, "Hello world")
    }

    func testSendMessageClearsInputText() async {
        let (vm, _, _) = makeLoadedViewModel(tokens: ["ok"])
        vm.inputText = "test"
        await vm.sendMessage()
        XCTAssertEqual(vm.inputText, "")
    }

    func testSendMessageDoesNothingWhenModelNotLoaded() async {
        // llm.isLoaded = false (default in setUp)
        viewModel.inputText = "test"
        await viewModel.sendMessage()
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testSendMessageDoesNothingForEmptyInput() async {
        let (vm, _, _) = makeLoadedViewModel()
        vm.inputText = "   "
        await vm.sendMessage()
        XCTAssertTrue(vm.messages.isEmpty)
    }

    func testSendMessageSetsErrorOnLLMFailure() async throws {
        let (vm, llm, _) = makeLoadedViewModel()
        llm.shouldThrowOnGenerate = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "model error"])
        vm.inputText = "hi"
        await vm.sendMessage()
        let msg = try XCTUnwrap(vm.errorMessage)
        XCTAssertTrue(msg.contains("model error"))
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

    // MARK: - sendMessage concurrency

    func testSendMessageIsNoOpWhileAlreadyGenerating() async {
        let (vm, llm, _) = makeLoadedViewModel(tokens: ["hi"])
        llm.isGenerating = true   // simulate in-flight generation
        vm.inputText = "second"
        await vm.sendMessage()
        XCTAssertTrue(vm.messages.isEmpty)
    }

    // MARK: - sendMessage edge cases

    func testSendMessageEmptyTokenStreamLeavesBlankAssistantMessage() async {
        let (vm, _, _) = makeLoadedViewModel(tokens: [])
        vm.inputText = "hi"
        await vm.sendMessage()
        XCTAssertEqual(vm.messages.count, 2)
        XCTAssertEqual(vm.messages[1].role, .assistant)
        XCTAssertTrue(vm.messages[1].content.isEmpty)
    }

    // MARK: - clearHistory edge cases

    func testClearHistoryDuringGenerationCancelsLLM() {
        let (vm, llm, _) = makeLoadedViewModel(tokens: ["a", "b"])
        llm.isGenerating = true
        vm.clearHistory()
        XCTAssertTrue(vm.messages.isEmpty)
        XCTAssertTrue(llm.cancelCalled)
    }

    // MARK: - CalendarAction regex edge cases

    func testDisplayContentHandlesNestedBracesInJSON() {
        // JSON value containing `}` inside a string must not prematurely close the block
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

    /// Helper: appends a blank assistant message and returns its index.
    private func appendAssistantMessage() -> Int {
        viewModel.messages.append(ChatMessage(role: .assistant, content: ""))
        return viewModel.messages.count - 1
    }

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
        // "<thi" is a valid prefix of "<think>" — must not display anything
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
}
