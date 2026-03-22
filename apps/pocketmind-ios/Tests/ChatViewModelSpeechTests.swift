import XCTest
@testable import PocketMind

/// Tests for the speech recording lifecycle in ChatViewModel:
/// toggleSpeech / confirmSpeech / cancelSpeech and their interaction
/// with the transcript subscriber and auto-send logic.
@MainActor
final class ChatViewModelSpeechTests: XCTestCase {

    var speech: MockSpeechService!
    var settings: MockAppSettings!
    var viewModel: ChatViewModel!

    override func setUp() async throws {
        try await super.setUp()
        speech = MockSpeechService()
        settings = MockAppSettings()
        viewModel = ChatViewModel(
            llmService: MockLLMService(),
            calendarService: MockCalendarService(),
            settings: settings,
            systemPromptBuilder: MockSystemPromptBuilder(),
            suggestedPromptsProvider: MockSuggestedPromptsProvider(),
            speechService: speech,
            hapticService: MockHapticService(),
            historyManager: MockChatHistoryManager()
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        speech = nil
        settings = nil
        try await super.tearDown()
    }

    // MARK: - toggleSpeech (start path)

    func testToggleSpeechStartsRecordingWhenIdle() {
        viewModel.toggleSpeech()
        XCTAssertTrue(speech.startCalled)
        XCTAssertTrue(viewModel.isSpeechRecording)
    }

    func testToggleSpeechResetsDiscardFlagBeforeStart() {
        viewModel.discardNextTranscript = true
        viewModel.toggleSpeech()
        XCTAssertFalse(viewModel.discardNextTranscript)
    }

    func testToggleSpeechSetsErrorOnStartFailure() throws {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "fake" }
        }
        speech.shouldThrowOnStart = FakeError()
        viewModel.toggleSpeech()
        XCTAssertEqual(viewModel.errorMessage, "fake")
        XCTAssertFalse(viewModel.isSpeechRecording)
    }

    // MARK: - toggleSpeech (stop path → confirmSpeech)

    func testToggleSpeechCallsConfirmWhenRecording() {
        viewModel.toggleSpeech()   // start
        viewModel.toggleSpeech()   // stop → confirm
        XCTAssertTrue(speech.stopCalled)
    }

    func testToggleSpeechStopDoesNotSuppressAutoSend() {
        viewModel.toggleSpeech()   // start
        viewModel.toggleSpeech()   // stop via confirm
        XCTAssertFalse(viewModel.suppressSpeechAutoSend)
    }

    // MARK: - confirmSpeech

    func testConfirmSpeechStopsRecording() {
        viewModel.toggleSpeech()
        viewModel.confirmSpeech()
        XCTAssertTrue(speech.stopCalled)
        XCTAssertEqual(speech.stopRecordingCallCount, 1)
    }

    func testConfirmSpeechIsNoOpWhenNotRecording() {
        viewModel.confirmSpeech()
        XCTAssertFalse(speech.stopCalled)
        XCTAssertEqual(speech.stopRecordingCallCount, 0)
    }

    func testConfirmSpeechDoesNotSetDiscardFlag() {
        viewModel.toggleSpeech()
        viewModel.confirmSpeech()
        XCTAssertFalse(viewModel.discardNextTranscript)
    }

    func testConfirmSpeechAllowsAutoSendWhenSettingEnabled() {
        let llm = MockLLMService()
        llm.isLoaded = true
        let vm = ChatViewModel(
            llmService: llm,
            calendarService: MockCalendarService(),
            settings: settings,
            systemPromptBuilder: MockSystemPromptBuilder(),
            suggestedPromptsProvider: MockSuggestedPromptsProvider(),
            speechService: speech,
            hapticService: MockHapticService(),
            historyManager: MockChatHistoryManager()
        )
        settings.speechAutoSendEnabled = true
        vm.toggleSpeech()
        speech.simulateTranscript("send this")
        vm.confirmSpeech()
        speech.simulateRecordingEnded()
        // auto-send fires: sendMessage() is called → isGenerating becomes true
        XCTAssertFalse(vm.suppressSpeechAutoSend)
    }

    // MARK: - cancelSpeech

    func testCancelSpeechStopsRecording() {
        viewModel.toggleSpeech()
        viewModel.cancelSpeech()
        XCTAssertTrue(speech.stopCalled)
    }

    func testCancelSpeechIsNoOpWhenNotRecording() {
        viewModel.cancelSpeech()
        XCTAssertFalse(speech.stopCalled)
    }

    func testCancelSpeechSetsDiscardFlag() {
        viewModel.toggleSpeech()
        viewModel.cancelSpeech()
        XCTAssertTrue(viewModel.discardNextTranscript)
    }

    func testCancelSpeechSuppressesAutoSend() {
        viewModel.toggleSpeech()
        viewModel.cancelSpeech()
        XCTAssertTrue(viewModel.suppressSpeechAutoSend)
    }

    func testCancelSpeechClearsInputTextWhenRecordingEnds() {
        viewModel.inputText = "some previous text"
        viewModel.toggleSpeech()
        speech.simulateTranscript("hello world")   // sets inputText
        viewModel.cancelSpeech()
        speech.simulateRecordingEnded()            // fires isRecording=false sink
        XCTAssertTrue(viewModel.inputText.isEmpty)
    }

    func testCancelSpeechResetsDiscardFlagAfterRecordingEnds() {
        viewModel.toggleSpeech()
        viewModel.cancelSpeech()
        speech.simulateRecordingEnded()
        XCTAssertFalse(viewModel.discardNextTranscript)
    }

    func testCancelSpeechResetsSuppressFlagAfterRecordingEnds() {
        viewModel.toggleSpeech()
        viewModel.cancelSpeech()
        speech.simulateRecordingEnded()
        XCTAssertFalse(viewModel.suppressSpeechAutoSend)
    }

    // MARK: - Transcript subscriber

    func testTranscriptUpdatesInputText() {
        viewModel.toggleSpeech()
        speech.simulateTranscript("hello")
        XCTAssertEqual(viewModel.inputText, "hello")
    }

    func testEmptyTranscriptDoesNotClearInputText() {
        viewModel.inputText = "typed text"
        viewModel.toggleSpeech()
        speech.simulateTranscript("")
        XCTAssertEqual(viewModel.inputText, "typed text")
    }

    func testTranscriptBlockedWhenDiscardFlagSet() {
        viewModel.inputText = "original"
        viewModel.discardNextTranscript = true
        speech.simulateTranscript("should be ignored")
        XCTAssertEqual(viewModel.inputText, "original")
    }

    // MARK: - isSpeechRecording / isSpeechTranscribing mirrors

    func testIsSpeechRecordingMirrorsServiceState() {
        XCTAssertFalse(viewModel.isSpeechRecording)
        viewModel.toggleSpeech()
        XCTAssertTrue(viewModel.isSpeechRecording)
        speech.simulateRecordingEnded()
        XCTAssertFalse(viewModel.isSpeechRecording)
    }

    func testIsSpeechTranscribingMirrorsServiceState() {
        XCTAssertFalse(viewModel.isSpeechTranscribing)
        speech.simulateTranscribing(true)
        XCTAssertTrue(viewModel.isSpeechTranscribing)
        speech.simulateTranscribing(false)
        XCTAssertFalse(viewModel.isSpeechTranscribing)
    }

    // MARK: - Second recording session

    func testSecondRecordingSessionStartsCleanly() {
        // First session
        viewModel.toggleSpeech()
        speech.simulateTranscript("first")
        viewModel.confirmSpeech()
        speech.simulateRecordingEnded()

        // Second session — discardNextTranscript must be reset
        viewModel.toggleSpeech()
        XCTAssertFalse(viewModel.discardNextTranscript)
        XCTAssertTrue(viewModel.isSpeechRecording)
    }

    func testSecondSessionTranscriptUpdatesInputText() {
        // First session
        viewModel.toggleSpeech()
        speech.simulateTranscript("first")
        viewModel.confirmSpeech()
        speech.simulateRecordingEnded()

        // Second session
        viewModel.toggleSpeech()
        speech.simulateTranscript("second")
        XCTAssertEqual(viewModel.inputText, "second")
    }

    func testCancelThenStartNewSessionDoesNotDiscard() {
        // Cancel first session
        viewModel.toggleSpeech()
        viewModel.cancelSpeech()
        speech.simulateRecordingEnded()

        // Start new session — discard flag must be cleared
        viewModel.toggleSpeech()
        speech.simulateTranscript("new transcript")
        XCTAssertEqual(viewModel.inputText, "new transcript")
    }
}
