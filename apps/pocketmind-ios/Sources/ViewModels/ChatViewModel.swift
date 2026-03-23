import Combine
import Foundation
import OSLog

private let llmLogger = Logger(subsystem: "app.pocketmind", category: "LLM")

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published private(set) var isGenerating = false
    @Published private(set) var isPreparing = false
    @Published private(set) var isModelLoaded = false
    @Published var errorMessage: String?
    @Published var toast: ToastItem?

    @Published private(set) var isSpeechRecording = false
    @Published private(set) var isSpeechAvailable = false
    @Published private(set) var isSpeechTranscribing = false
    @Published private(set) var isAutoListening = false

    @Published var suggestedPrompts: [String] = []
    @Published var isGeneratingSuggestions = false

    /// Per-session thinking mode toggle — true means the model reasons before answering.
    @Published var thinkingEnabled: Bool = false

    /// Message the user is replying to — shown as a quote strip above the input bar.
    @Published var replyingTo: ChatMessage? = nil

    /// Navigation title — equals session title in session mode, "PocketMind" otherwise.
    @Published private(set) var sessionTitle: String

    let llmService: any LLMServiceProtocol
    let calendarService: any CalendarServiceProtocol
    let settings: any AppSettingsProtocol
    let systemPromptBuilder: any SystemPromptBuilderProtocol
    let suggestedPromptsProvider: any SuggestedPromptsProviderProtocol
    let speechService: any SpeechServiceProtocol
    let hapticService: any HapticServiceProtocol
    let history: any ChatHistoryManagerProtocol
    let airPodsCoordinator: (any AirPodsVoiceCoordinatorProtocol)?
    let webSearchService: (any WebSearchServiceProtocol)?
    private var errorDismissTask: Task<Void, Never>?
    var cancellables = Set<AnyCancellable>()
    // Prevents auto-submit when the user manually taps the mic button to stop recording
    var suppressSpeechAutoSend = false
    // Set to true when voice auto-start triggered recording — preserves auto-send on manual stop
    var voiceAutoStartActive = false
    // When true, the next transcript result is discarded instead of written to inputText
    var discardNextTranscript = false

    /// Mirrors settings.voiceAutoStartEnabled — exposed so ChatView never touches settings directly.
    @Published private(set) var voiceAutoStartEnabled: Bool

    /// If set, ChatView auto-sends this message on appear (used for Siri integration).
    var pendingInput: String?
    /// If true, ChatView starts voice recording on appear regardless of voiceAutoStartEnabled.
    var pendingVoiceStart = false

    // Session-mode properties — nil when operating in legacy single-history mode.
    let sessionID: UUID?
    let sessionCreatedAt: Date
    let sessionManager: (any SessionManagerProtocol)?
    private var onSessionUpdated: ((@MainActor (ChatSessionMeta) -> Void))?

    init(
        dependencies: ChatViewModelDependencies,
        session: ChatSession? = nil,
        sessionManager: (any SessionManagerProtocol)? = nil,
        onSessionUpdated: ((@MainActor (ChatSessionMeta) -> Void))? = nil,
        pendingInput: String? = nil
    ) {
        self.llmService = dependencies.llmService
        self.calendarService = dependencies.calendarService
        self.settings = dependencies.settings
        self.systemPromptBuilder = dependencies.systemPromptBuilder
        self.suggestedPromptsProvider = dependencies.suggestedPromptsProvider
        self.speechService = dependencies.speechService
        self.hapticService = dependencies.hapticService
        self.history = session != nil ? NoOpChatHistoryManager() : dependencies.historyManager
        self.airPodsCoordinator = dependencies.airPodsCoordinator
        self.webSearchService = dependencies.webSearchService
        self.sessionID = session?.id
        self.sessionCreatedAt = session?.createdAt ?? .now
        self.sessionManager = sessionManager
        self.onSessionUpdated = onSessionUpdated
        self.sessionTitle = session?.title ?? "PocketMind"
        self.pendingInput = pendingInput
        self.voiceAutoStartEnabled = dependencies.settings.voiceAutoStartEnabled
        self.isModelLoaded = dependencies.llmService.isLoaded

        var loaded = session?.messages ?? dependencies.historyManager.load()
        ChatViewModel.sanitizeStaleState(&loaded)
        self.messages = loaded

        setupPublishers()

        // Request speech permissions on launch
        Task { [weak self] in await self?.speechService.requestAuthorization() }

        // If model is already loaded and there's nothing to show, kick off suggestions.
        if dependencies.llmService.isLoaded && messages.isEmpty && pendingInput == nil {
            Task { [weak self] in await self?.generateSuggestedPrompts() }
        }
    }

    func cancelGeneration() {
        llmService.cancelGeneration()
    }

    func cancelSuggestionsGeneration() {
        isGeneratingSuggestions = false
    }

    func generateSuggestedPrompts() async {
        guard !isGeneratingSuggestions else { return }
        suggestedPrompts = suggestedPromptsProvider.buildPrompts()
    }

    /// Checks all active calendar event previews against EventKit and marks
    /// any whose underlying event no longer exists as stale.
    func refreshStalePreviews() {
        guard calendarService.isAuthorized else { return }
        let activeStates: Set<CalendarEventPreview.PreviewState> = [.created, .updated, .rescheduled, .restored]
        for msgIdx in messages.indices {
            for prevIdx in messages[msgIdx].calendarEventPreviews.indices {
                let preview = messages[msgIdx].calendarEventPreviews[prevIdx]
                guard activeStates.contains(preview.state),
                      let eid = preview.eventIdentifier,
                      !preview.isStale else { continue }
                if calendarService.calendarName(forEventIdentifier: eid) == nil {
                    messages[msgIdx].calendarEventPreviews[prevIdx].isStale = true
                }
            }
        }
    }

    /// Receives a query from Siri and sends it as if the user typed it.
    func handleSiriQuery(_ text: String) {
        inputText = text
        Task { [weak self] in await self?.sendMessage() }
    }

    func deleteMessage(id: UUID) {
        messages.removeAll { $0.id == id }
    }

    func needsDateSeparator(at index: Int) -> Bool {
        guard index < messages.count else { return false }
        guard index > 0 else { return true }
        return !Calendar.current.isDate(messages[index].timestamp, inSameDayAs: messages[index - 1].timestamp)
    }
}
