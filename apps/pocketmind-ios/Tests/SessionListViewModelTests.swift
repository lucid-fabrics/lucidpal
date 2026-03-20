import XCTest
@testable import PocketMind

@MainActor
final class SessionListViewModelTests: XCTestCase {
    var mock: MockSessionManager!
    var llm: MockLLMService!
    var calendarService: MockCalendarService!
    var controller: MockCalendarActionController!
    var settings: AppSettings!
    var speech: MockSpeechService!
    var viewModel: SessionListViewModel!

    override func setUp() async throws {
        mock = MockSessionManager()
        llm = MockLLMService()
        calendarService = MockCalendarService()
        controller = MockCalendarActionController()
        settings = AppSettings()
        speech = MockSpeechService()
        viewModel = SessionListViewModel(
            sessionManager: mock,
            llmService: llm,
            calendarService: calendarService,
            calendarActionController: controller,
            settings: settings,
            speechService: speech,
            hapticService: MockHapticService()
        )
    }

    // MARK: - Init

    func testInitLoadsIndexSortedByUpdatedAt() {
        let old = ChatSessionMeta(id: UUID(), title: "Old", createdAt: .now, updatedAt: Date(timeIntervalSinceNow: -3600))
        let recent = ChatSessionMeta(id: UUID(), title: "Recent", createdAt: .now, updatedAt: .now)
        // Pre-populate the mock store
        mock.save(ChatSession(id: old.id, title: old.title, createdAt: old.createdAt, updatedAt: old.updatedAt, messages: []))
        mock.save(ChatSession(id: recent.id, title: recent.title, createdAt: recent.createdAt, updatedAt: recent.updatedAt, messages: []))

        let vm = SessionListViewModel(
            sessionManager: mock,
            llmService: llm,
            calendarService: calendarService,
            calendarActionController: controller,
            settings: settings,
            speechService: speech,
            hapticService: MockHapticService()
        )
        XCTAssertEqual(vm.sessions.first?.id, recent.id)
        XCTAssertEqual(vm.sessions.last?.id, old.id)
    }

    // MARK: - createSession

    func testCreateSessionAddsToPublishedSessions() {
        XCTAssertTrue(viewModel.sessions.isEmpty)
        viewModel.createSession()
        XCTAssertEqual(viewModel.sessions.count, 1)
    }

    func testCreateSessionSavesViaManager() {
        viewModel.createSession()
        XCTAssertEqual(mock.savedSessions.count, 1)
    }

    func testCreateSessionInsertsAtTop() {
        viewModel.createSession()
        let second = viewModel.createSession()
        XCTAssertEqual(viewModel.sessions.first?.id, second.id)
    }

    func testCreateSessionReturnsNewChatTitle() {
        let session = viewModel.createSession()
        XCTAssertEqual(session.title, "New Chat")
    }

    // MARK: - deleteSession

    func testDeleteSessionRemovesFromPublishedSessions() {
        let session = viewModel.createSession()
        viewModel.deleteSession(id: session.id)
        XCTAssertTrue(viewModel.sessions.isEmpty)
    }

    func testDeleteSessionCallsManagerDelete() {
        let session = viewModel.createSession()
        viewModel.deleteSession(id: session.id)
        XCTAssertEqual(mock.deletedIDs, [session.id])
    }

    func testDeleteUnknownIDIsNoOp() {
        viewModel.createSession()
        viewModel.deleteSession(id: UUID())
        XCTAssertEqual(viewModel.sessions.count, 1)
    }

    // MARK: - sessionUpdated

    func testSessionUpdatedRefreshesTitleInList() {
        let session = viewModel.createSession()
        var updated = session.meta
        updated.title = "Renamed"
        viewModel.sessionUpdated(updated)
        XCTAssertEqual(viewModel.sessions.first?.title, "Renamed")
    }

    func testSessionUpdatedBubblesToTop() {
        let first = viewModel.createSession()
        let second = viewModel.createSession()
        // second is currently at top; update first to bubble it up
        var updatedFirst = first.meta
        updatedFirst.title = "Now Top"
        viewModel.sessionUpdated(updatedFirst)
        XCTAssertEqual(viewModel.sessions.first?.id, first.id)
    }

    func testSessionUpdatedUnknownIDIsNoOp() {
        viewModel.createSession()
        let count = viewModel.sessions.count
        let unknown = ChatSessionMeta(id: UUID(), title: "Ghost", createdAt: .now, updatedAt: .now)
        viewModel.sessionUpdated(unknown)
        XCTAssertEqual(viewModel.sessions.count, count)
    }

    // MARK: - loadFullSession

    func testLoadFullSessionReturnsStoredSession() {
        let session = viewModel.createSession()
        let loaded = viewModel.loadFullSession(meta: session.meta)
        XCTAssertEqual(loaded.id, session.id)
    }

    func testLoadFullSessionReturnsFallbackForUnknownID() {
        let meta = ChatSessionMeta(id: UUID(), title: "Ghost", createdAt: .now, updatedAt: .now)
        let fallback = viewModel.loadFullSession(meta: meta)
        XCTAssertEqual(fallback.id, meta.id)
        XCTAssertTrue(fallback.messages.isEmpty)
    }

    // MARK: - makeChatViewModel

    func testMakeChatViewModelUsesSessionMessages() {
        let msg = ChatMessage(role: .user, content: "test")
        let session = ChatSession(id: UUID(), title: "T", createdAt: .now, updatedAt: .now, messages: [msg])
        mock.save(session)
        let vm = viewModel.makeChatViewModel(for: session)
        XCTAssertEqual(vm.messages.count, 1)
        XCTAssertEqual(vm.messages.first?.content, "test")
    }

    func testMakeChatViewModelWithInitialQuerySetsPendingInput() {
        let session = ChatSession.new()
        let vm = viewModel.makeChatViewModel(for: session, initialQuery: "What's on my calendar?")
        XCTAssertEqual(vm.pendingInput, "What's on my calendar?")
    }

    // MARK: - renameSession

    func testRenameSessionUpdatesTitle() {
        let session = viewModel.createSession()
        viewModel.renameSession(id: session.id, title: "Weekly Standup")
        XCTAssertEqual(viewModel.sessions.first?.title, "Weekly Standup")
    }

    func testRenameSessionCallsManagerRename() {
        let session = viewModel.createSession()
        viewModel.renameSession(id: session.id, title: "Sprint Retro")
        let stored = mock.loadSession(id: session.id)
        XCTAssertEqual(stored?.title, "Sprint Retro")
    }

    func testRenameSessionUnknownIDIsNoOp() {
        viewModel.createSession()
        let countBefore = viewModel.sessions.count
        viewModel.renameSession(id: UUID(), title: "Ghost")
        XCTAssertEqual(viewModel.sessions.count, countBefore)
        XCTAssertNotEqual(viewModel.sessions.first?.title, "Ghost")
    }

    // MARK: - scheduleCreateEvent

    func testScheduleCreateEventSetsPendingEventCreation() {
        let event = SiriPendingEvent(title: "Dentist", date: Date(timeIntervalSinceNow: 3600))
        viewModel.scheduleCreateEvent(event)
        XCTAssertEqual(viewModel.pendingEventCreation?.title, "Dentist")
    }

    func testScheduleCreateEventPreservesDate() {
        let date = Date(timeIntervalSinceNow: 7200)
        let event = SiriPendingEvent(title: "Meeting", date: date)
        viewModel.scheduleCreateEvent(event)
        XCTAssertEqual(viewModel.pendingEventCreation?.date, date)
    }

    func testScheduleCreateEventOverwritesPreviousPending() {
        viewModel.scheduleCreateEvent(SiriPendingEvent(title: "First", date: .now))
        viewModel.scheduleCreateEvent(SiriPendingEvent(title: "Second", date: .now))
        XCTAssertEqual(viewModel.pendingEventCreation?.title, "Second")
    }

    // MARK: - createCalendarEvent

    func testCreateCalendarEventDelegatesToCalendarService() throws {
        let start = Date(timeIntervalSinceNow: 3600)
        let end = Date(timeIntervalSinceNow: 7200)
        try viewModel.createCalendarEvent(
            title: "Team Sync", start: start, end: end,
            isAllDay: false, location: nil, notes: nil
        )
        XCTAssertEqual(calendarService.createdEvents.count, 1)
        XCTAssertEqual(calendarService.createdEvents.first?.title, "Team Sync")
    }

    func testCreateCalendarEventPassesAllDayFlag() throws {
        let start = Date(timeIntervalSinceNow: 0)
        let end = Date(timeIntervalSinceNow: 0)
        try viewModel.createCalendarEvent(
            title: "Holiday", start: start, end: end,
            isAllDay: true, location: nil, notes: nil
        )
        XCTAssertEqual(calendarService.createdEvents.first?.isAllDay, true)
    }

    func testCreateCalendarEventPassesCorrectDates() throws {
        let start = Date(timeIntervalSinceNow: 1000)
        let end = Date(timeIntervalSinceNow: 5000)
        try viewModel.createCalendarEvent(
            title: "Lunch", start: start, end: end,
            isAllDay: false, location: "Cafe", notes: "Bring laptop"
        )
        XCTAssertEqual(calendarService.createdEvents.first?.start, start)
        XCTAssertEqual(calendarService.createdEvents.first?.end, end)
    }

    // MARK: - scheduleSiriQuery

    func testScheduleSiriQueryCreatesSession() {
        viewModel.scheduleSiriQuery("Remind me about dentist")
        XCTAssertEqual(viewModel.sessions.count, 1)
    }

    func testScheduleSiriQuerySetsSiriNavigationMeta() throws {
        viewModel.scheduleSiriQuery("What's happening tomorrow?")
        let meta = try XCTUnwrap(viewModel.siriNavigationMeta)
        XCTAssertFalse(meta.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
    }

    func testScheduleSiriQueryStoresPendingQuery() {
        viewModel.scheduleSiriQuery("Check my schedule")
        let sessionID = viewModel.sessions.first!.id
        XCTAssertEqual(viewModel.pendingQueryBySessionID[sessionID], "Check my schedule")
    }
}
