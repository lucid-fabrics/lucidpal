import Foundation

@MainActor
final class SessionListViewModel: ObservableObject {
    @Published var sessions: [ChatSessionMeta] = []

    /// Set by PocketMindApp when a Siri query arrives.
    /// SessionListView observes this to navigate to the new session.
    @Published var siriNavigationMeta: ChatSessionMeta?

    /// Set by PocketMindApp when a Siri "Add Event" intent provides event details.
    /// SessionListView presents CreateEventSheet when non-nil.
    @Published var pendingEventCreation: SiriPendingEvent?

    /// Keyed by session ID — consumed by ChatSessionContainer on init to auto-send the first message.
    var pendingQueryBySessionID: [UUID: String] = [:]

    let sessionManager: any SessionManagerProtocol
    let llmService: any LLMServiceProtocol
    let calendarService: any CalendarServiceProtocol
    let calendarActionController: any CalendarActionControllerProtocol
    let settings: any AppSettingsProtocol
    let speechService: any SpeechServiceProtocol
    let hapticService: any HapticServiceProtocol

    init(
        sessionManager: any SessionManagerProtocol,
        llmService: any LLMServiceProtocol,
        calendarService: any CalendarServiceProtocol,
        calendarActionController: any CalendarActionControllerProtocol,
        settings: any AppSettingsProtocol,
        speechService: any SpeechServiceProtocol,
        hapticService: any HapticServiceProtocol
    ) {
        self.sessionManager = sessionManager
        self.llmService = llmService
        self.calendarService = calendarService
        self.calendarActionController = calendarActionController
        self.settings = settings
        self.speechService = speechService
        self.hapticService = hapticService
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

    func sessionUpdated(_ meta: ChatSessionMeta) {
        guard let i = sessions.firstIndex(where: { $0.id == meta.id }) else { return }
        sessions[i] = meta
        // Bubble updated session to the top
        let updated = sessions.remove(at: i)
        sessions.insert(updated, at: 0)
    }

    // MARK: - ChatViewModel Factory

    func makeChatViewModel(for session: ChatSession, initialQuery: String? = nil) -> ChatViewModel {
        ChatViewModel(
            llmService: llmService,
            calendarService: calendarService,
            calendarActionController: calendarActionController,
            settings: settings,
            speechService: speechService,
            hapticService: hapticService,
            historyManager: NoOpChatHistoryManager(),
            session: session,
            sessionManager: sessionManager,
            onSessionUpdated: { [weak self] meta in
                self?.sessionUpdated(meta)
            },
            pendingInput: initialQuery
        )
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

    func scheduleCreateEvent(_ event: SiriPendingEvent) {
        pendingEventCreation = event
    }

    func createCalendarEvent(
        title: String, start: Date, end: Date,
        isAllDay: Bool, location: String?, notes: String?
    ) throws {
        try calendarService.createEvent(
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
