import XCTest
@testable import PocketMind

@MainActor
final class CalendarConfirmationTests: XCTestCase {

    var llm: MockLLMService!
    var calendar: MockCalendarService!
    var controller: MockCalendarActionController!
    var haptic: MockHapticService!
    var vm: ChatViewModel!

    override func setUp() async throws {
        llm = MockLLMService()
        llm.isLoaded = true
        calendar = MockCalendarService()
        controller = MockCalendarActionController()
        haptic = MockHapticService()
        vm = ChatViewModel(
            llmService: llm,
            calendarService: calendar,
            calendarActionController: controller,
            settings: MockAppSettings(),
            speechService: MockSpeechService(),
            hapticService: haptic,
            historyManager: NoOpChatHistoryManager()
        )
    }

    // MARK: - Helpers

    private func addMessageWithPreviews(_ previews: [CalendarEventPreview]) -> UUID {
        var msg = ChatMessage(role: .assistant, content: "Done.")
        msg.calendarEventPreviews = previews
        vm.messages.append(msg)
        return msg.id
    }

    private func preview(state: CalendarEventPreview.PreviewState = .pendingDeletion) -> CalendarEventPreview {
        CalendarEventPreview(
            title: "Dentist",
            start: Date(timeIntervalSinceNow: 3600),
            end: Date(timeIntervalSinceNow: 7200),
            calendarName: "Personal",
            state: state,
            eventIdentifier: "evt-001"
        )
    }

    // MARK: - indices()

    func testIndicesReturnsNilForUnknownMessageID() {
        let result = vm.indices(messageID: UUID(), previewID: UUID())
        XCTAssertNil(result)
    }

    func testIndicesReturnsNilForUnknownPreviewID() {
        let msgID = addMessageWithPreviews([preview()])
        let result = vm.indices(messageID: msgID, previewID: UUID())
        XCTAssertNil(result)
    }

    func testIndicesReturnsCorrectPair() {
        let p = preview()
        let msgID = addMessageWithPreviews([p])
        let result = vm.indices(messageID: msgID, previewID: p.id)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, vm.messages.count - 1)
        XCTAssertEqual(result?.1, 0)
    }

    // MARK: - cancelDeletion

    func testCancelDeletionSetsStateToDeletionCancelled() {
        let p = preview(state: .pendingDeletion)
        let msgID = addMessageWithPreviews([p])
        vm.cancelDeletion(messageID: msgID, previewID: p.id)
        let state = vm.messages.last?.calendarEventPreviews.first?.state
        XCTAssertEqual(state, .deletionCancelled)
    }

    func testCancelDeletionTriggersHaptic() {
        let p = preview()
        let msgID = addMessageWithPreviews([p])
        vm.cancelDeletion(messageID: msgID, previewID: p.id)
        XCTAssertTrue(haptic.impactCalled)
    }

    func testCancelDeletionNoOpForUnknownID() {
        vm.cancelDeletion(messageID: UUID(), previewID: UUID())
        XCTAssertFalse(haptic.impactCalled)
    }

    // MARK: - cancelAllDeletions

    func testCancelAllDeletionsSetsPendingToDetelionCancelled() {
        let p1 = preview(state: .pendingDeletion)
        var p2 = preview(state: .pendingDeletion)
        p2 = CalendarEventPreview(title: "Gym", start: p2.start, end: p2.end, calendarName: "Work",
                                  state: .pendingDeletion, eventIdentifier: "evt-002")
        let msgID = addMessageWithPreviews([p1, p2])
        vm.cancelAllDeletions(messageID: msgID)
        let states = vm.messages.last?.calendarEventPreviews.map(\.state) ?? []
        XCTAssertTrue(states.allSatisfy { $0 == .deletionCancelled })
    }

    func testCancelAllDeletionsIgnoresNonPendingPreviews() {
        var p = preview(state: .created)
        p = CalendarEventPreview(title: "Meeting", start: p.start, end: p.end, calendarName: "Work",
                                 state: .created, eventIdentifier: "evt-003")
        let msgID = addMessageWithPreviews([p])
        vm.cancelAllDeletions(messageID: msgID)
        XCTAssertEqual(vm.messages.last?.calendarEventPreviews.first?.state, .created)
    }

    // MARK: - cancelUpdate

    func testCancelUpdateSetsStateToUpdateCancelled() {
        var p = preview(state: .pendingUpdate)
        var update = PendingCalendarUpdate()
        update.title = "New Title"
        p.pendingUpdate = update
        let msgID = addMessageWithPreviews([p])
        vm.cancelUpdate(messageID: msgID, previewID: p.id)
        let updatedPreview = vm.messages.last?.calendarEventPreviews.first
        XCTAssertEqual(updatedPreview?.state, .updateCancelled)
        XCTAssertNil(updatedPreview?.pendingUpdate)
    }

    func testCancelUpdateTriggersHaptic() {
        let p = preview(state: .pendingUpdate)
        let msgID = addMessageWithPreviews([p])
        vm.cancelUpdate(messageID: msgID, previewID: p.id)
        XCTAssertTrue(haptic.impactCalled)
    }

    // MARK: - confirmDeletion

    func testConfirmDeletionSetsStateToDeleted() async {
        calendar.shouldThrowOnDelete = false
        let p = preview(state: .pendingDeletion)
        let msgID = addMessageWithPreviews([p])
        await vm.confirmDeletion(messageID: msgID, previewID: p.id)
        XCTAssertEqual(vm.messages.last?.calendarEventPreviews.first?.state, .deleted)
    }

    func testConfirmDeletionSetsErrorMessageOnFailure() async {
        calendar.shouldThrowOnDelete = true
        let p = preview(state: .pendingDeletion)
        let msgID = addMessageWithPreviews([p])
        await vm.confirmDeletion(messageID: msgID, previewID: p.id)
        XCTAssertNotNil(vm.errorMessage)
    }

    func testConfirmDeletionTriggersHapticOnSuccess() async {
        calendar.shouldThrowOnDelete = false
        let p = preview(state: .pendingDeletion)
        let msgID = addMessageWithPreviews([p])
        await vm.confirmDeletion(messageID: msgID, previewID: p.id)
        XCTAssertTrue(haptic.notifySuccessCalled)
    }
}
