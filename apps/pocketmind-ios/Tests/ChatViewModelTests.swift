import XCTest
@testable import PocketMind

@MainActor
final class ChatViewModelTests: XCTestCase {
    var mock: MockCalendarService!
    var settings: AppSettings!
    var controller: CalendarActionController!
    var llm: LLMService!
    var viewModel: ChatViewModel!

    override func setUp() {
        super.setUp()
        mock = MockCalendarService()
        settings = AppSettings()
        controller = CalendarActionController(calendarService: mock, settings: settings)
        llm = LLMService()
        viewModel = ChatViewModel(
            llmService: llm,
            calendarService: mock,
            calendarActionController: controller,
            settings: settings
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

    func testConfirmAllDeletionsPartialFailureSetsErrorMessage() async {
        mock.shouldThrowOnDelete = true
        let (msgID, _) = insertMessage(state: .pendingDeletion)
        await viewModel.confirmAllDeletions(messageID: msgID)
        let state = viewModel.messages.first?.calendarEventPreviews.first?.state
        XCTAssertEqual(state, .deletionCancelled)
        XCTAssertNotNil(viewModel.errorMessage)
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

    func testConfirmUpdateMirrorsFieldsAndSetsState() async {
        var pending = PendingCalendarUpdate()
        pending.title = "Renamed"
        pending.start = Date(timeIntervalSinceNow: 7200)
        pending.end   = Date(timeIntervalSinceNow: 10800)
        let (msgID, previewID) = insertMessage(state: .pendingUpdate, pendingUpdate: pending)

        await viewModel.confirmUpdate(messageID: msgID, previewID: previewID)

        let preview = viewModel.messages.first?.calendarEventPreviews.first
        XCTAssertEqual(preview?.title, "Renamed")
        XCTAssertNotNil(preview?.start)
        XCTAssertTrue(preview?.state == .updated || preview?.state == .rescheduled)
        XCTAssertNil(preview?.pendingUpdate)
        XCTAssertEqual(mock.appliedUpdates.count, 1)
    }

    func testConfirmUpdateEventNotFoundSetsErrorMessage() async {
        mock.shouldThrowOnApplyUpdate = true
        var pending = PendingCalendarUpdate()
        pending.title = "Oops"
        let (msgID, previewID) = insertMessage(state: .pendingUpdate, pendingUpdate: pending)

        await viewModel.confirmUpdate(messageID: msgID, previewID: previewID)

        let state = viewModel.messages.first?.calendarEventPreviews.first?.state
        XCTAssertEqual(state, .updateCancelled)
        XCTAssertNotNil(viewModel.errorMessage)
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
}
