import XCTest

@testable import LucidPal

// swiftlint:disable file_length type_body_length
@MainActor
final class SessionListViewModelTests: XCTestCase {
    var mock: MockSessionManager!
    var llm: MockLLMService!
    var calendarService: MockCalendarService!
    var controller: MockCalendarActionController!
    var settings: AppSettingsProtocol!
    var speech: MockSpeechService!
    var viewModel: SessionListViewModel!

    override func setUp() async throws {
        mock = MockSessionManager()
        llm = MockLLMService()
        calendarService = MockCalendarService()
        controller = MockCalendarActionController()
        settings = MockAppSettings()
        speech = MockSpeechService()
        viewModel = SessionListViewModel(
            sessionManager: mock,
            dependencies: SessionListViewModelDependencies(
                llmService: llm,

                calendarService: calendarService,
                calendarActionController: controller,
                settings: settings,
                speechService: speech,
                hapticService: MockHapticService(),
                contextService: MockContextService()
            )
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
            dependencies: SessionListViewModelDependencies(
                llmService: llm,

                calendarService: calendarService,
                calendarActionController: controller,
                settings: settings,
                speechService: speech,
                hapticService: MockHapticService(),
                contextService: MockContextService()
            )
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

    // MARK: - groupedSessions

    func testGroupedSessionsEmptyWhenNoSessions() {
        XCTAssertTrue(viewModel.groupedSessions(searchText: "").isEmpty)
    }

    func testGroupedSessionsTodayBucket() {
        let session = viewModel.createSession()
        // createSession sets updatedAt = .now, so it should land in "Today"
        let groups = viewModel.groupedSessions(searchText: "")
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.title, "Today")
        XCTAssertEqual(groups.first?.sessions.first?.id, session.id)
    }

    func testGroupedSessionsEarlierBucket() throws {
        // Manually insert a session with an old updatedAt
        let id = UUID()
        let old = ChatSession(
            id: id,
            title: "Old Chat",
            createdAt: Date(timeIntervalSinceNow: -30 * 86400),
            updatedAt: Date(timeIntervalSinceNow: -30 * 86400),
            messages: []
        )
        mock.save(old)
        viewModel.sessions.insert(old.meta, at: 0)
        let groups = viewModel.groupedSessions(searchText: "")
        XCTAssertTrue(groups.contains { $0.title == "Earlier" })
        let earlierGroup = try XCTUnwrap(groups.first { $0.title == "Earlier" })
        XCTAssertTrue(earlierGroup.sessions.contains { $0.id == id })
    }

    // MARK: - filteredSessions

    func testFilteredSessionsEmptyQueryReturnsAll() {
        viewModel.createSession()
        viewModel.createSession()
        XCTAssertEqual(viewModel.filteredSessions(searchText: "").count, 2)
    }

    func testFilteredSessionsCaseInsensitiveMatch() {
        viewModel.createSession()
        viewModel.renameSession(id: viewModel.sessions[0].id, title: "Swift Tips")
        let results = viewModel.filteredSessions(searchText: "swift")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Swift Tips")
    }

    func testFilteredSessionsNoMatchReturnsEmpty() {
        viewModel.createSession()
        viewModel.renameSession(id: viewModel.sessions[0].id, title: "Swift Tips")
        XCTAssertTrue(viewModel.filteredSessions(searchText: "zzz").isEmpty)
    }

    // MARK: - nextUpcomingEvent

    func testNextUpcomingEventNilWhenCalendarDisabled() {
        calendarService.isAuthorized = false
        XCTAssertNil(viewModel.nextUpcomingEvent())
    }

    func testNextUpcomingEventReturnsFirstNonAllDayEvent() {
        calendarService.isAuthorized = true
        let soon = Date(timeIntervalSinceNow: 3600)
        let event = CalendarEventInfo(
            eventIdentifier: "1",
            title: "Team Sync",
            startDate: soon,
            endDate: soon.addingTimeInterval(3600),
            isAllDay: false,
            calendarTitle: "Work"
        )
        calendarService.stubbedEvents = [event]
        let result = viewModel.nextUpcomingEvent()
        XCTAssertEqual(result?.title, "Team Sync")
    }

    // MARK: - todayEventCount

    func testTodayEventCountZeroWhenCalendarDisabled() {
        calendarService.isAuthorized = false
        XCTAssertEqual(viewModel.todayEventCount(), 0)
    }

    func testTodayEventCountReturnsCorrectCount() {
        calendarService.isAuthorized = true
        let now = Date.now
        // swiftlint:disable:next line_length
        let e1 = CalendarEventInfo(eventIdentifier: "1", title: "A", startDate: now, endDate: now.addingTimeInterval(3600), isAllDay: false, calendarTitle: "Work")
        // swiftlint:disable:next line_length
        let e2 = CalendarEventInfo(eventIdentifier: "2", title: "B", startDate: now, endDate: now.addingTimeInterval(7200), isAllDay: false, calendarTitle: "Work")
        calendarService.stubbedEvents = [e1, e2]
        XCTAssertEqual(viewModel.todayEventCount(), 2)
    }

    // MARK: - scheduleSiriQuery

    func testScheduleSiriQueryCreatesSession() {
        viewModel.scheduleSiriQuery("Remind me about dentist")
        XCTAssertEqual(viewModel.sessions.count, 1)
    }

    func testScheduleSiriQuerySetsSiriNavigationMeta() throws {
        viewModel.scheduleSiriQuery("What's happening tomorrow?")
        let meta = try XCTUnwrap(viewModel.siriNavigationMeta)
        let zeroID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")
        XCTAssertNotEqual(meta.id, zeroID)
    }

    func testScheduleSiriQueryStoresPendingQuery() throws {
        viewModel.scheduleSiriQuery("Check my schedule")
        let sessionID = try XCTUnwrap(viewModel.sessions.first).id
        XCTAssertEqual(viewModel.pendingQueryBySessionID[sessionID], "Check my schedule")
    }

    func testScheduleSiriQueryEmptyStringSetsPendingQueryToEmpty() throws {
        viewModel.scheduleSiriQuery("")
        let sessionID = try XCTUnwrap(viewModel.sessions.first).id
        XCTAssertEqual(viewModel.pendingQueryBySessionID[sessionID], "")
    }

    // MARK: - groupedSessions

    func testGroupedSessionsEmptySessionsProducesNoGroups() {
        let groups = viewModel.groupedSessions(searchText: "")
        XCTAssertTrue(groups.allSatisfy { $0.sessions.isEmpty })
    }

    func testGroupedSessionsTodaySessionGoesToTodayBucket() {
        let id = UUID()
        mock.save(ChatSession(id: id, title: "Today Session", createdAt: .now, updatedAt: .now, messages: []))
        viewModel = SessionListViewModel(
            sessionManager: mock,
            dependencies: SessionListViewModelDependencies(
                llmService: llm,
                calendarService: calendarService,
                calendarActionController: controller, settings: settings,
                speechService: speech, hapticService: MockHapticService(), contextService: MockContextService()
            )
        )
        let groups = viewModel.groupedSessions(searchText: "")
        let todayGroup = groups.first { $0.title == "Today" }
        XCTAssertEqual(todayGroup?.sessions.first?.id, id)
    }

    func testGroupedSessionsOldSessionGoesToEarlierBucket() {
        let id = UUID()
        let oldDate = Date(timeIntervalSinceNow: -30 * 24 * 3600)
        mock.save(ChatSession(id: id, title: "Old Session", createdAt: oldDate, updatedAt: oldDate, messages: []))
        viewModel = SessionListViewModel(
            sessionManager: mock,
            dependencies: SessionListViewModelDependencies(
                llmService: llm,
                calendarService: calendarService,
                calendarActionController: controller, settings: settings,
                speechService: speech, hapticService: MockHapticService(), contextService: MockContextService()
            )
        )
        let groups = viewModel.groupedSessions(searchText: "")
        let earlierGroup = groups.first { $0.title == "Earlier" }
        XCTAssertEqual(earlierGroup?.sessions.first?.id, id)
    }

    // MARK: - nextUpcomingEvent

    func testNextUpcomingEventReturnsNilWhenCalendarUnauthorized() {
        calendarService.isAuthorized = false
        XCTAssertNil(viewModel.nextUpcomingEvent())
    }

    func testNextUpcomingEventReturnsNilWhenNoEvents() {
        calendarService.isAuthorized = true
        calendarService.stubbedEvents = []
        XCTAssertNil(viewModel.nextUpcomingEvent())
    }

    // MARK: - todayEventCount

    func testTodayEventCountReturnsZeroWhenCalendarUnauthorized() {
        calendarService.isAuthorized = false
        XCTAssertEqual(viewModel.todayEventCount(), 0)
    }

    func testTodayEventCountExcludesAllDayEvents() {
        calendarService.isAuthorized = true
        let allDay = CalendarEventInfo(
            eventIdentifier: "1", title: "Holiday",
            startDate: .now, endDate: .now,
            isAllDay: true, calendarTitle: "Personal"
        )
        calendarService.stubbedEvents = [allDay]
        XCTAssertEqual(viewModel.todayEventCount(), 0)
    }

    func testTodayEventCountIncludesTimedEvents() {
        calendarService.isAuthorized = true
        let event = CalendarEventInfo(
            eventIdentifier: "1", title: "Meeting",
            startDate: .now, endDate: Date(timeIntervalSinceNow: 3600),
            isAllDay: false, calendarTitle: "Work"
        )
        calendarService.stubbedEvents = [event]
        XCTAssertEqual(viewModel.todayEventCount(), 1)
    }
}
// swiftlint:enable file_length type_body_length
