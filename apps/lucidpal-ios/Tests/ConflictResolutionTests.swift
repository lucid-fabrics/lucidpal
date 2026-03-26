import XCTest

@testable import LucidPal

@MainActor
final class ConflictResolutionTests: XCTestCase {

    var llm: MockLLMService!
    var calendar: MockCalendarService!
    var haptic: MockHapticService!
    var vm: ChatViewModel!

    override func setUp() async throws {
        llm = MockLLMService()
        llm.isLoaded = true
        calendar = MockCalendarService()
        haptic = MockHapticService()
        vm = ChatViewModel(dependencies: ChatViewModelDependencies(
            llmService: llm,
            calendarService: calendar,
            settings: MockAppSettings(),
            systemPromptBuilder: MockSystemPromptBuilder(),
            suggestedPromptsProvider: MockSuggestedPromptsProvider(),
            speechService: MockSpeechService(),
            hapticService: haptic,
            historyManager: NoOpChatHistoryManager(),
            airPodsCoordinator: nil,
            webSearchService: nil
        ))
    }

    // MARK: - Helpers

    private func makeConflictingPreview(identifier: String = "evt-conflict") -> CalendarEventPreview {
        let conflict = ConflictingEventSnapshot(
            title: "Existing Meeting",
            start: Date(timeIntervalSinceNow: 3600),
            end: Date(timeIntervalSinceNow: 7200),
            calendarName: "Work",
            isRecurring: false,
            isAllDay: false
        )
        var p = CalendarEventPreview(
            title: "New Event",
            start: Date(timeIntervalSinceNow: 3600),
            end: Date(timeIntervalSinceNow: 7200),
            calendarName: "Personal",
            state: .created,
            eventIdentifier: identifier
        )
        p.hasConflict = true
        p.conflictingEvents = [conflict]
        return p
    }

    private func addMessage(with preview: CalendarEventPreview) -> (msgID: UUID, previewID: UUID) {
        var msg = ChatMessage(role: .assistant, content: "Done.")
        msg.calendarEventPreviews = [preview]
        vm.messages.append(msg)
        return (msg.id, preview.id)
    }

    // MARK: - keepConflict

    func testKeepConflictClearsHasConflict() {
        let p = makeConflictingPreview()
        let (msgID, previewID) = addMessage(with: p)
        vm.keepConflict(messageID: msgID, previewID: previewID)
        XCTAssertEqual(vm.messages.last?.calendarEventPreviews.first?.hasConflict, false)
    }

    func testKeepConflictClearsConflictingEvents() {
        let p = makeConflictingPreview()
        let (msgID, previewID) = addMessage(with: p)
        vm.keepConflict(messageID: msgID, previewID: previewID)
        XCTAssertTrue(vm.messages.last?.calendarEventPreviews.first?.conflictingEvents.isEmpty ?? false)
    }

    func testKeepConflictPreservesState() {
        let p = makeConflictingPreview()
        let (msgID, previewID) = addMessage(with: p)
        vm.keepConflict(messageID: msgID, previewID: previewID)
        XCTAssertEqual(vm.messages.last?.calendarEventPreviews.first?.state, .created)
    }

    func testKeepConflictNoOpForUnknownIDs() {
        vm.keepConflict(messageID: UUID(), previewID: UUID())
        XCTAssertTrue(vm.messages.isEmpty)
    }

    // MARK: - cancelConflict

    func testCancelConflictDeletesEventFromCalendar() async throws {
        let p = makeConflictingPreview(identifier: "evt-001")
        let (msgID, previewID) = addMessage(with: p)
        await vm.cancelConflict(messageID: msgID, previewID: previewID)
        XCTAssertTrue(calendar.deletedIdentifiers.contains("evt-001"))
    }

    func testCancelConflictSetsStateToDeleted() async throws {
        let p = makeConflictingPreview()
        let (msgID, previewID) = addMessage(with: p)
        await vm.cancelConflict(messageID: msgID, previewID: previewID)
        XCTAssertEqual(vm.messages.last?.calendarEventPreviews.first?.state, .deleted)
    }

    func testCancelConflictSetsErrorOnDeleteFailure() async throws {
        calendar.shouldThrowOnDelete = true
        let p = makeConflictingPreview()
        let (msgID, previewID) = addMessage(with: p)
        await vm.cancelConflict(messageID: msgID, previewID: previewID)
        let errorMsg = try XCTUnwrap(vm.errorMessage)
        XCTAssertFalse(errorMsg.isEmpty)
    }

    func testCancelConflictNoOpWhenEventIdentifierNil() async throws {
        var p = makeConflictingPreview()
        p.eventIdentifier = nil
        let (msgID, previewID) = addMessage(with: p)
        await vm.cancelConflict(messageID: msgID, previewID: previewID)
        XCTAssertTrue(calendar.deletedIdentifiers.isEmpty)
    }

    // MARK: - findFreeSlotsForConflict

    func testFindFreeSlotsReturnsAvailableSlots() async throws {
        calendar.stubbedEvents = []
        let p = makeConflictingPreview()
        let (msgID, previewID) = addMessage(with: p)
        let slots = await vm.findFreeSlotsForConflict(messageID: msgID, previewID: previewID)
        XCTAssertFalse(slots.isEmpty)
    }

    func testFindFreeSlotsReturnsEmptyForUnknownID() async throws {
        let slots = await vm.findFreeSlotsForConflict(messageID: UUID(), previewID: UUID())
        XCTAssertTrue(slots.isEmpty)
    }

    // MARK: - rescheduleConflict

    func testRescheduleConflictAppliesUpdateToCalendar() async throws {
        let p = makeConflictingPreview(identifier: "evt-reschedule")
        let (msgID, previewID) = addMessage(with: p)
        let slotStart = Date(timeIntervalSinceNow: 10800)
        let slotEnd = Date(timeIntervalSinceNow: 14400)
        await vm.rescheduleConflict(messageID: msgID, previewID: previewID, to: CalendarFreeSlot(start: slotStart, end: slotEnd))
        let (update, identifier) = try XCTUnwrap(calendar.appliedUpdates.first)
        XCTAssertEqual(identifier, "evt-reschedule")
        XCTAssertEqual(update.start, slotStart)
        XCTAssertEqual(update.end, slotEnd)
    }

    func testRescheduleConflictClearsConflictFlag() async throws {
        let p = makeConflictingPreview()
        let (msgID, previewID) = addMessage(with: p)
        await vm.rescheduleConflict(
            messageID: msgID, previewID: previewID,
            to: CalendarFreeSlot(start: Date(timeIntervalSinceNow: 10800), end: Date(timeIntervalSinceNow: 14400))
        )
        XCTAssertEqual(vm.messages.last?.calendarEventPreviews.first?.hasConflict, false)
    }

    func testRescheduleConflictSetsStateToRescheduled() async throws {
        let p = makeConflictingPreview()
        let (msgID, previewID) = addMessage(with: p)
        await vm.rescheduleConflict(
            messageID: msgID, previewID: previewID,
            to: CalendarFreeSlot(start: Date(timeIntervalSinceNow: 10800), end: Date(timeIntervalSinceNow: 14400))
        )
        XCTAssertEqual(vm.messages.last?.calendarEventPreviews.first?.state, .rescheduled)
    }

    func testRescheduleConflictNoOpForUnknownID() async throws {
        await vm.rescheduleConflict(
            messageID: UUID(), previewID: UUID(),
            to: CalendarFreeSlot(start: Date(), end: Date())
        )
        XCTAssertTrue(calendar.appliedUpdates.isEmpty)
    }

    func testRescheduleConflictSetsErrorMessageOnFailure() async throws {
        calendar.shouldThrowOnApplyUpdate = true
        let p = makeConflictingPreview()
        let (msgID, previewID) = addMessage(with: p)
        await vm.rescheduleConflict(
            messageID: msgID, previewID: previewID,
            to: CalendarFreeSlot(start: Date(timeIntervalSinceNow: 10800), end: Date(timeIntervalSinceNow: 14400))
        )
        let errorMsg = try XCTUnwrap(vm.errorMessage)
        XCTAssertFalse(errorMsg.isEmpty)
    }

    func testRescheduleConflictPreservesStateOnFailure() async throws {
        calendar.shouldThrowOnApplyUpdate = true
        let p = makeConflictingPreview()
        let (msgID, previewID) = addMessage(with: p)
        await vm.rescheduleConflict(
            messageID: msgID, previewID: previewID,
            to: CalendarFreeSlot(start: Date(timeIntervalSinceNow: 10800), end: Date(timeIntervalSinceNow: 14400))
        )
        // State should be unchanged — error, not rescheduled
        XCTAssertEqual(vm.messages.last?.calendarEventPreviews.first?.state, .created)
    }
}
