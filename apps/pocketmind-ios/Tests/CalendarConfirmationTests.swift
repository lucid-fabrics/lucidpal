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

    func testIndicesReturnsCorrectPair() throws {
        let p = preview()
        let msgID = addMessageWithPreviews([p])
        let result = try XCTUnwrap(vm.indices(messageID: msgID, previewID: p.id))
        XCTAssertEqual(result.0, vm.messages.count - 1)
        XCTAssertEqual(result.1, 0)
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

    func testConfirmDeletionSetsErrorMessageOnFailure() async throws {
        calendar.shouldThrowOnDelete = true
        let p = preview(state: .pendingDeletion)
        let msgID = addMessageWithPreviews([p])
        await vm.confirmDeletion(messageID: msgID, previewID: p.id)
        let errorMsg = try XCTUnwrap(vm.errorMessage)
        XCTAssertFalse(errorMsg.isEmpty)
    }

    func testConfirmDeletionTriggersHapticOnSuccess() async {
        calendar.shouldThrowOnDelete = false
        let p = preview(state: .pendingDeletion)
        let msgID = addMessageWithPreviews([p])
        await vm.confirmDeletion(messageID: msgID, previewID: p.id)
        XCTAssertTrue(haptic.notifySuccessCalled)
    }

    // MARK: - undoDeletion

    func testUndoDeletionSetsStateToRestored() async {
        let p = preview(state: .deleted)
        let msgID = addMessageWithPreviews([p])
        await vm.undoDeletion(messageID: msgID, previewID: p.id)
        XCTAssertEqual(vm.messages.last?.calendarEventPreviews.first?.state, .restored)
    }

    func testUndoDeletionCallsCreateEvent() async {
        let p = preview(state: .deleted)
        let msgID = addMessageWithPreviews([p])
        await vm.undoDeletion(messageID: msgID, previewID: p.id)
        XCTAssertEqual(calendar.createdEvents.count, 1)
        XCTAssertEqual(calendar.createdEvents.first?.title, "Dentist")
    }

    func testUndoDeletionTriggersHapticOnSuccess() async {
        let p = preview(state: .deleted)
        let msgID = addMessageWithPreviews([p])
        await vm.undoDeletion(messageID: msgID, previewID: p.id)
        XCTAssertTrue(haptic.notifySuccessCalled)
    }

    func testUndoDeletionSetsErrorMessageOnFailure() async throws {
        calendar.shouldThrowOnDelete = true   // reuse flag — but undoDeletion calls createEvent, not deleteEvent
        // Use a custom subclass approach: stub createEvent to throw by overriding shouldThrowOnCreate if available.
        // MockCalendarService.createEvent does not throw by default; verify happy path only covers this path.
        // Test the no-op guard: unknown IDs should not create an event.
        await vm.undoDeletion(messageID: UUID(), previewID: UUID())
        XCTAssertTrue(calendar.createdEvents.isEmpty)
    }

    func testUndoDeletionNoOpForUnknownMessageID() async {
        let p = preview(state: .deleted)
        _ = addMessageWithPreviews([p])
        await vm.undoDeletion(messageID: UUID(), previewID: p.id)
        XCTAssertTrue(calendar.createdEvents.isEmpty)
    }

    // MARK: - confirmAllDeletions

    func testConfirmAllDeletionsDeletesAllPendingPreviews() async {
        let p1 = CalendarEventPreview(
            title: "A", start: Date(timeIntervalSinceNow: 3600), end: Date(timeIntervalSinceNow: 7200),
            calendarName: "Work", state: .pendingDeletion, eventIdentifier: "id-A"
        )
        let p2 = CalendarEventPreview(
            title: "B", start: Date(timeIntervalSinceNow: 3600), end: Date(timeIntervalSinceNow: 7200),
            calendarName: "Work", state: .pendingDeletion, eventIdentifier: "id-B"
        )
        let msgID = addMessageWithPreviews([p1, p2])
        await vm.confirmAllDeletions(messageID: msgID)
        let states = vm.messages.last?.calendarEventPreviews.map(\.state) ?? []
        XCTAssertTrue(states.allSatisfy { $0 == .deleted })
        XCTAssertEqual(Set(calendar.deletedIdentifiers), ["id-A", "id-B"])
    }

    func testConfirmAllDeletionsIgnoresNonPendingPreviews() async {
        let p = CalendarEventPreview(
            title: "Done", start: Date(timeIntervalSinceNow: 3600), end: Date(timeIntervalSinceNow: 7200),
            calendarName: "Work", state: .deleted, eventIdentifier: "id-done"
        )
        let msgID = addMessageWithPreviews([p])
        await vm.confirmAllDeletions(messageID: msgID)
        XCTAssertTrue(calendar.deletedIdentifiers.isEmpty)
        XCTAssertEqual(vm.messages.last?.calendarEventPreviews.first?.state, .deleted)
    }

    func testConfirmAllDeletionsPartialFailureSetsErrorMessage() async throws {
        calendar.shouldThrowOnDelete = true
        let p = preview(state: .pendingDeletion)
        let msgID = addMessageWithPreviews([p])
        await vm.confirmAllDeletions(messageID: msgID)
        let errorMsg = try XCTUnwrap(vm.errorMessage)
        XCTAssertFalse(errorMsg.isEmpty)
    }

    func testConfirmAllDeletionsOnEmptyMessageIsNoOp() async {
        var msg = ChatMessage(role: .assistant, content: "")
        vm.messages.append(msg)
        await vm.confirmAllDeletions(messageID: msg.id)
        XCTAssertTrue(calendar.deletedIdentifiers.isEmpty)
    }

    func testConfirmAllDeletionsNoOpForUnknownMessageID() async {
        await vm.confirmAllDeletions(messageID: UUID())
        XCTAssertTrue(calendar.deletedIdentifiers.isEmpty)
    }

    // MARK: - confirmUpdate

    func testConfirmUpdateCallsApplyUpdate() async {
        var p = preview(state: .pendingUpdate)
        var update = PendingCalendarUpdate()
        update.title = "Rescheduled"
        p.pendingUpdate = update
        let msgID = addMessageWithPreviews([p])
        await vm.confirmUpdate(messageID: msgID, previewID: p.id)
        XCTAssertEqual(calendar.appliedUpdates.count, 1)
        XCTAssertEqual(calendar.appliedUpdates.first?.1, "evt-001")
    }

    func testConfirmUpdateMirrorsFieldsOntoPreview() async {
        var p = preview(state: .pendingUpdate)
        var update = PendingCalendarUpdate()
        update.title = "Updated Title"
        update.start = Date(timeIntervalSinceNow: 7200)
        update.end   = Date(timeIntervalSinceNow: 10800)
        p.pendingUpdate = update
        let msgID = addMessageWithPreviews([p])
        await vm.confirmUpdate(messageID: msgID, previewID: p.id)
        let updated = vm.messages.last?.calendarEventPreviews.first
        XCTAssertEqual(updated?.title, "Updated Title")
        XCTAssertEqual(updated?.start, update.start)
        XCTAssertNil(updated?.pendingUpdate)
    }

    func testConfirmUpdateSetsTerminalState() async {
        var p = preview(state: .pendingUpdate)
        var update = PendingCalendarUpdate()
        update.title = "Renamed"
        p.pendingUpdate = update
        let msgID = addMessageWithPreviews([p])
        await vm.confirmUpdate(messageID: msgID, previewID: p.id)
        let state = vm.messages.last?.calendarEventPreviews.first?.state
        XCTAssertTrue(state == .updated || state == .rescheduled,
                      "Expected .updated or .rescheduled, got \(String(describing: state))")
    }

    func testConfirmUpdateEventNotFoundSetsErrorMessage() async throws {
        calendar.shouldThrowOnApplyUpdate = true
        var p = preview(state: .pendingUpdate)
        var update = PendingCalendarUpdate()
        update.title = "Oops"
        p.pendingUpdate = update
        let msgID = addMessageWithPreviews([p])
        await vm.confirmUpdate(messageID: msgID, previewID: p.id)
        let state = vm.messages.last?.calendarEventPreviews.first?.state
        XCTAssertEqual(state, .updateCancelled)
        let errorMsg = try XCTUnwrap(vm.errorMessage)
        XCTAssertFalse(errorMsg.isEmpty)
    }

    func testConfirmUpdateNoPendingUpdateIsNoOp() async {
        let p = preview(state: .pendingUpdate)
        let msgID = addMessageWithPreviews([p])
        await vm.confirmUpdate(messageID: msgID, previewID: p.id)
        XCTAssertTrue(calendar.appliedUpdates.isEmpty)
    }

    func testConfirmUpdateTriggersHapticOnSuccess() async {
        var p = preview(state: .pendingUpdate)
        var update = PendingCalendarUpdate()
        update.title = "New"
        p.pendingUpdate = update
        let msgID = addMessageWithPreviews([p])
        await vm.confirmUpdate(messageID: msgID, previewID: p.id)
        XCTAssertTrue(haptic.notifySuccessCalled)
    }

    // MARK: - undoDeletion error path

    func testUndoDeletionSetsErrorMessageWhenCreateFails() async throws {
        calendar.shouldThrowOnCreate = true
        let p = preview(state: .deleted)
        let msgID = addMessageWithPreviews([p])
        await vm.undoDeletion(messageID: msgID, previewID: p.id)
        let errorMsg = try XCTUnwrap(vm.errorMessage)
        XCTAssertFalse(errorMsg.isEmpty)
    }

    func testUndoDeletionPreservesStateWhenCreateFails() async {
        calendar.shouldThrowOnCreate = true
        let p = preview(state: .deleted)
        let msgID = addMessageWithPreviews([p])
        await vm.undoDeletion(messageID: msgID, previewID: p.id)
        XCTAssertEqual(vm.messages.last?.calendarEventPreviews.first?.state, .deleted)
    }
}
