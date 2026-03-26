import Foundation

@MainActor
final class SessionListViewModel: ObservableObject {
    @Published var sessions: [ChatSessionMeta] = []

    /// Set by LucidPalApp when a Siri query arrives.
    /// SessionListView observes this to navigate to the new session.
    @Published var siriNavigationMeta: ChatSessionMeta?

    /// Set by LucidPalApp when a Siri "Add Event" intent provides event details.
    /// SessionListView presents CreateEventSheet when non-nil.
    @Published var pendingEventCreation: SiriPendingEvent?

    /// Keyed by session ID — consumed by ChatSessionContainer on init to auto-send the first message.
    var pendingQueryBySessionID: [UUID: String] = [:]

    private let sessionManager: any SessionManagerProtocol
    private let deps: SessionListViewModelDependencies
    private let makeSystemPromptBuilder: () -> any SystemPromptBuilderProtocol
    private let makeSuggestedPromptsProvider: () -> any SuggestedPromptsProviderProtocol

    init(
        sessionManager: any SessionManagerProtocol,
        dependencies: SessionListViewModelDependencies
    ) {
        self.sessionManager = sessionManager
        self.deps = dependencies
        self.makeSystemPromptBuilder = dependencies.makeSystemPromptBuilder ?? {
            SystemPromptBuilder(
                calendarService: dependencies.calendarService,
                contextService: dependencies.contextService,
                settings: dependencies.settings,
                calendarActionController: dependencies.calendarActionController
            )
        }
        self.makeSuggestedPromptsProvider = dependencies.makeSuggestedPromptsProvider ?? {
            SuggestedPromptsProvider(calendarService: dependencies.calendarService)
        }
        self.sessions = sessionManager.loadIndex().sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Session CRUD

    @discardableResult
    func createSession() -> ChatSession {
        let session = ChatSession.new()
        sessionManager.save(session)
        sessions.insert(session.meta, at: 0)
        return session
    }

    func deleteSession(id: UUID) {
        sessionManager.delete(id: id)
        sessions.removeAll { $0.id == id }
    }

    func renameSession(id: UUID, title: String) {
        guard let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[i].title = title
        sessionManager.renameSession(id: id, title: title)
    }

    func togglePin(id: UUID) {
        guard let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[i].isPinned.toggle()
        sessionManager.togglePin(id: id)
    }

    func refreshSessions() {
        sessions = sessionManager.loadIndex().sorted { $0.updatedAt > $1.updatedAt }
    }

    func sessionUpdated(_ meta: ChatSessionMeta) {
        guard let i = sessions.firstIndex(where: { $0.id == meta.id }) else { return }
        sessions[i] = meta
        // Bubble updated session to the top
        let updated = sessions.remove(at: i)
        sessions.insert(updated, at: 0)
    }

    // MARK: - ChatViewModel Factory

    func makeChatViewModel(for session: ChatSession, initialQuery: String? = nil, startWithVoice: Bool = false) -> ChatViewModel {
        let chatDeps = ChatViewModelDependencies(
            llmService: deps.llmService,
            calendarService: deps.calendarService,
            settings: deps.settings,
            systemPromptBuilder: makeSystemPromptBuilder(),
            suggestedPromptsProvider: makeSuggestedPromptsProvider(),
            speechService: deps.speechService,
            hapticService: deps.hapticService,
            historyManager: NoOpChatHistoryManager(),
            airPodsCoordinator: deps.airPodsCoordinator,
            webSearchService: deps.webSearchService
        )
        let vm = ChatViewModel(
            dependencies: chatDeps,
            session: session,
            sessionManager: sessionManager,
            onSessionUpdated: { [weak self] meta in
                self?.sessionUpdated(meta)
            },
            pendingInput: initialQuery
        )
        vm.pendingVoiceStart = startWithVoice
        return vm
    }

    func loadFullSession(meta: ChatSessionMeta) -> ChatSession {
        sessionManager.loadSession(id: meta.id) ?? ChatSession(
            id: meta.id,
            title: meta.title,
            createdAt: meta.createdAt,
            updatedAt: meta.updatedAt,
            messages: []
        )
    }

    // MARK: - Siri

    func scheduleSiriQuery(_ query: String) {
        let session = createSession()
        pendingQueryBySessionID[session.id] = query
        siriNavigationMeta = session.meta
    }

    // MARK: - Calendar context for hero panel

    func nextUpcomingEvent() -> CalendarEventInfo? {
        guard deps.calendarService.isAuthorized else { return nil }
        let now = Date.now
        let end = Calendar.current.date(byAdding: .hour, value: 24, to: now) ?? now.addingTimeInterval(24 * ChatConstants.secondsPerHour)
        return deps.calendarService.events(in: now, end: end)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    func todayEventCount() -> Int {
        guard deps.calendarService.isAuthorized else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * ChatConstants.secondsPerHour)
        return deps.calendarService.events(in: start, end: end)
            .filter { !$0.isAllDay }
            .count
    }

    // MARK: - Session Grouping

    struct SessionGroup {
        let title: String
        let sessions: [ChatSessionMeta]
    }

    func filteredSessions(searchText: String) -> [ChatSessionMeta] {
        guard !searchText.isEmpty else { return sessions }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    func groupedSessions(searchText: String) -> [SessionGroup] {
        let cal = Calendar.current
        let now = Date.now
        let filtered = filteredSessions(searchText: searchText)

        let pinned = filtered.filter(\.isPinned)
        let unpinned = filtered.filter { !$0.isPinned }

        var today: [ChatSessionMeta] = []
        var yesterday: [ChatSessionMeta] = []
        var thisWeek: [ChatSessionMeta] = []
        var earlier: [ChatSessionMeta] = []

        for meta in unpinned {
            if cal.isDateInToday(meta.updatedAt) {
                today.append(meta)
            } else if cal.isDateInYesterday(meta.updatedAt) {
                yesterday.append(meta)
            } else if let weekAgo = cal.date(byAdding: .day, value: -7, to: now),
                      meta.updatedAt >= weekAgo {
                thisWeek.append(meta)
            } else {
                earlier.append(meta)
            }
        }

        var groups: [SessionGroup] = []
        if !pinned.isEmpty {
            groups.append(SessionGroup(title: "Pinned", sessions: pinned))
        }
        groups.append(contentsOf: [
            SessionGroup(title: "Today", sessions: today),
            SessionGroup(title: "Yesterday", sessions: yesterday),
            SessionGroup(title: "This Week", sessions: thisWeek),
            SessionGroup(title: "Earlier", sessions: earlier),
        ].filter { !$0.sessions.isEmpty })
        return groups
    }

    func scheduleCreateEvent(_ event: SiriPendingEvent) {
        pendingEventCreation = event
    }

    func createCalendarEvent(
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        location: String?,
        notes: String?
    ) throws {
        try deps.calendarService.createEvent(
            title: title,
            start: start,
            end: end,
            location: location,
            notes: notes,
            reminderMinutes: nil,
            calendarIdentifier: nil,
            isAllDay: isAllDay,
            recurrence: nil,
            recurrenceEnd: nil
        )
    }
}
