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
        llmService: any LLMServiceProtocol,
        calendarService: any CalendarServiceProtocol,
        settings: any AppSettingsProtocol,
        systemPromptBuilder: any SystemPromptBuilderProtocol,
        suggestedPromptsProvider: any SuggestedPromptsProviderProtocol,
        speechService: any SpeechServiceProtocol,
        hapticService: any HapticServiceProtocol,
        historyManager: any ChatHistoryManagerProtocol,
        airPodsCoordinator: (any AirPodsVoiceCoordinatorProtocol)? = nil,
        webSearchService: (any WebSearchServiceProtocol)? = nil,
        // Session-mode params — pass these to enable multi-session persistence.
        session: ChatSession? = nil,
        sessionManager: (any SessionManagerProtocol)? = nil,
        onSessionUpdated: ((@MainActor (ChatSessionMeta) -> Void))? = nil,
        pendingInput: String? = nil
    ) {
        self.llmService = llmService
        self.calendarService = calendarService
        self.settings = settings
        self.systemPromptBuilder = systemPromptBuilder
        self.suggestedPromptsProvider = suggestedPromptsProvider
        self.speechService = speechService
        self.hapticService = hapticService
        self.history = session != nil ? NoOpChatHistoryManager() : historyManager
        self.airPodsCoordinator = airPodsCoordinator
        self.webSearchService = webSearchService
        self.sessionID = session?.id
        self.sessionCreatedAt = session?.createdAt ?? .now
        self.sessionManager = sessionManager
        self.onSessionUpdated = onSessionUpdated
        self.sessionTitle = session?.title ?? "PocketMind"
        self.pendingInput = pendingInput
        self.voiceAutoStartEnabled = settings.voiceAutoStartEnabled
        self.isModelLoaded = llmService.isLoaded

        // Load messages: from session if in session mode, else from history file.
        var loaded = session?.messages ?? historyManager.load()
        ChatViewModel.sanitizeStaleState(&loaded)
        self.messages = loaded

        setupPublishers()

        // Request speech permissions on launch
        Task { [weak self] in await self?.speechService.requestAuthorization() }

        // If model is already loaded and there's nothing to show, kick off suggestions.
        if llmService.isLoaded && messages.isEmpty && pendingInput == nil {
            Task { [weak self] in await self?.generateSuggestedPrompts() }
        }
    }

    private func setupPublishers() {
        // Publishers — sink used instead of assign(to:) because existentials can't project @Published.
        llmService.isLoadedPublisher
            .sink { [weak self] loaded in
                self?.isModelLoaded = loaded
                guard loaded, self?.messages.isEmpty == true, self?.pendingInput == nil else { return }
                Task { [weak self] in await self?.generateSuggestedPrompts() }
            }
            .store(in: &cancellables)
        llmService.isGeneratingPublisher
            .sink { [weak self] in self?.isGenerating = $0 }
            .store(in: &cancellables)
        speechService.isRecordingPublisher
            .sink { [weak self] in self?.isSpeechRecording = $0 }
            .store(in: &cancellables)
        speechService.isAuthorizedPublisher
            .sink { [weak self] in self?.isSpeechAvailable = $0 }
            .store(in: &cancellables)
        speechService.isTranscribingPublisher
            .sink { [weak self] in self?.isSpeechTranscribing = $0 }
            .store(in: &cancellables)
        speechService.transcriptionErrorPublisher
            .compactMap { $0 }
            .sink { [weak self] in self?.errorMessage = $0 }
            .store(in: &cancellables)

        // Forward live transcript into the input field while recording
        speechService.transcriptPublisher
            .filter { !$0.isEmpty }
            .sink { [weak self] in
                guard let self, !self.discardNextTranscript else { return }
                self.inputText = $0
            }
            .store(in: &cancellables)

        // Observe AirPods auto-listening state
        airPodsCoordinator?.isAutoListeningPublisher
            .sink { [weak self] in self?.isAutoListening = $0 }
            .store(in: &cancellables)

        // Auto-dismiss error banner after errorAutoDismissSeconds
        $errorMessage
            .sink { [weak self] msg in
                self?.errorDismissTask?.cancel()
                guard msg != nil else { return }
                self?.errorDismissTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(ChatConstants.errorAutoDismissSeconds))
                    self?.errorMessage = nil
                }
            }
            .store(in: &cancellables)

        // Persist messages on change — debounced on MainActor, disk write offloaded to background.
        $messages
            .debounce(for: .seconds(ChatConstants.persistenceDebounceSeconds), scheduler: RunLoop.main)
            .sink { [weak self] msgs in
                guard let self else { return }
                if let sm = self.sessionManager, let sid = self.sessionID {
                    let session = ChatSession(
                        id: sid, title: self.sessionTitle,
                        createdAt: self.sessionCreatedAt, updatedAt: .now, messages: msgs
                    )
                    sm.save(session)
                    self.onSessionUpdated?(session.meta)
                } else {
                    self.history.save(msgs)
                }
            }
            .store(in: &cancellables)

        // Auto-submit when speech recognition ends naturally (final result / silence timeout).
        // If the user manually tapped the mic button to stop, suppressSpeechAutoSend is set
        // in toggleSpeech() and the observer skips the send.
        speechService.isRecordingPublisher
            .removeDuplicates()
            .filter { !$0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.discardNextTranscript {
                    self.discardNextTranscript = false
                    self.inputText = ""
                    self.suppressSpeechAutoSend = false
                    return
                }
                if self.suppressSpeechAutoSend {
                    self.suppressSpeechAutoSend = false
                    return
                }
                guard self.settings.speechAutoSendEnabled else { return }
                guard !self.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task { [weak self] in await self?.sendMessage() }
            }
            .store(in: &cancellables)
    }

    func toggleSpeech() {
        if speechService.isRecording {
            confirmSpeech()
        } else {
            discardNextTranscript = false
            do {
                try speechService.startRecording()
                hapticService.impact(.light)
            } catch {
                errorMessage = "Microphone error: \(error.localizedDescription)"
            }
        }
    }

    /// Stops recording and accepts the transcript. Auto-sends if the setting is enabled.
    func confirmSpeech() {
        guard speechService.isRecording else { return }
        voiceAutoStartActive = false
        speechService.stopRecording()
    }

    /// Stops recording and discards the transcript. Never auto-sends.
    func cancelSpeech() {
        guard speechService.isRecording else { return }
        suppressSpeechAutoSend = true
        discardNextTranscript = true
        voiceAutoStartActive = false
        speechService.stopRecording()
    }

    func sendMessage() async {
        cancelSuggestionsGeneration()
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating, isModelLoaded else { return }

        hapticService.impact(.light)
        inputText = ""
        replyingTo = nil
        messages.append(ChatMessage(role: .user, content: text))
        DebugLogStore.shared.log("USER: \(text)", category: "LLM")

        // Auto-title: derive session title from the first user message.
        if sessionManager != nil && sessionTitle == "New Chat" {
            sessionTitle = String(text.prefix(ChatConstants.maxSessionTitleLength))
        }
        errorMessage = nil

        // Build system prompt before showing the assistant placeholder —
        // prevents a visible empty bubble during the calendar fetch.
        isPreparing = true
        // defer guarantees isPreparing resets even if buildSystemPrompt() is extended
        // in the future to be throwing or if Swift runtime unwinds this frame.
        defer { isPreparing = false }
        let systemPrompt = await systemPromptBuilder.buildSystemPrompt()

        let assistantMsg = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMsg)
        let assistantID = assistantMsg.id  // Capture ID — safe against clearHistory() mid-stream

        // Snapshot history without the empty assistant placeholder.
        // Cap based on device RAM: 8 K context devices get more history (50 msgs ≈ 5000 tokens),
        // 4 K context devices use 20 msgs ≈ 2000 tokens, leaving headroom for system prompt + reply.
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / ChatConstants.bytesPerGB)
        let historyLimit = ramGB >= ChatConstants.largeContextRAMThresholdGB ? ChatConstants.largeHistoryLimit : ChatConstants.smallHistoryLimit
        let historyMessages = Array(messages.dropLast().suffix(historyLimit))

        let showThinking = thinkingEnabled  // snapshot at send time — also used by web search re-generation

        do {
            try await streamLLMResponse(
                systemPrompt: systemPrompt,
                messages: historyMessages,
                assistantID: assistantID,
                showThinking: showThinking
            )
            // Log raw LLM output for debugging
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                llmLogger.info("📤 USER: \(text, privacy: .public)")
                llmLogger.info("RAW_LLM: \(self.messages[idx].content, privacy: .public)")
                DebugLogStore.shared.log("RAW_LLM: \(messages[idx].content)", category: "LLM")
            }
        } catch is CancellationError {
            // User cancelled — leave partial content visible
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx].content = "Error: \(error.localizedDescription)"
            }
            errorMessage = error.localizedDescription
        }

        // Post-streaming: web search agentic loop (one iteration max) then calendar actions.
        if let idx = messages.firstIndex(where: { $0.id == assistantID }) {

            // Web search: if LLM output contains [WEB_SEARCH:{...}], execute and re-generate.
            if let searchSvc = webSearchService,
               settings.webSearchEnabled,
               let args = systemPromptBuilder.extractWebSearchQuery(from: messages[idx].content) {
                messages[idx].content = ""
                await performWebSearch(
                    query: args.query,
                    maxResults: args.maxResults,
                    searchSvc: searchSvc,
                    assistantID: assistantID,
                    showThinking: showThinking
                )
            } else if messages[idx].content.contains("[WEB_SEARCH:") {
                let rawContent = String(messages[idx].content.prefix(ChatConstants.rawLogPreviewLength))
                llmLogger.warning("🔍 WEB_SEARCH block detected but extractWebSearchQuery returned nil — content: '\(rawContent, privacy: .public)'")
            }

            // Calendar actions on final output (whether from first pass or post-search re-generation)
            if let finalIdx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[finalIdx].isThinking = false
                let (content, previews, freeSlots) = await systemPromptBuilder.executeCalendarActions(in: messages[finalIdx].content)
                messages[finalIdx].content = content
                messages[finalIdx].calendarEventPreviews = previews
                messages[finalIdx].calendarFreeSlots = freeSlots
                llmLogger.info("✅ FINAL: \(content, privacy: .public) | events=\(previews.count) slots=\(freeSlots.count)")
                DebugLogStore.shared.log("FINAL: events=\(previews.count) slots=\(freeSlots.count) — \(String(content.prefix(ChatConstants.rawLogPreviewLength)))", category: "LLM")
            }
        }
    }

    private func streamLLMResponse(
        systemPrompt: String,
        messages historyMessages: [ChatMessage],
        assistantID: UUID,
        showThinking: Bool
    ) async throws {
        var raw = ""           // full accumulated raw output
        var thinkDone = false  // have we seen </think> yet?

        for try await token in llmService.generate(systemPrompt: systemPrompt, messages: historyMessages, thinkingEnabled: showThinking) {
            guard let idx = messages.firstIndex(where: { $0.id == assistantID }) else { break }
            applyStreamToken(token, rawBuffer: &raw, thinkDone: &thinkDone, showThinking: showThinking, idx: idx)
        }
    }

    private func performWebSearch(
        query: String,
        maxResults: Int,
        searchSvc: any WebSearchServiceProtocol,
        assistantID: UUID,
        showThinking: Bool
    ) async {
        llmLogger.info("🔍 WEB_SEARCH extracted query='\(query, privacy: .public)' maxResults=\(maxResults)")
        DebugLogStore.shared.log("WEB_SEARCH query='\(query)' maxResults=\(maxResults)", category: "Search")
        do {
            let results = try await searchSvc.search(query: query, maxResults: maxResults)
            llmLogger.info("🔍 WEB_SEARCH got \(results.count) results for '\(query, privacy: .public)'")
            DebugLogStore.shared.log("WEB_SEARCH got \(results.count) results for '\(query)'", category: "Search")
            let resultText = results.enumerated().map { i, r in
                "[\(i + 1)] \(r.title)\nURL: \(r.url)\n\(r.snippet)"
            }.joined(separator: "\n\n")
            let toolMsg = ChatMessage(
                role: .user,
                content: "[SEARCH_RESULTS for \"\(query)\"]:\n\(resultText)\n\nAnswer the original question directly. No preamble. No disclaimers. Be concise. Use location/timezone from context."
            )
            let synthesisPrompt = await systemPromptBuilder.buildSynthesisPrompt()
            llmLogger.info("🔍 WEB_SEARCH starting synthesis pass")
            DebugLogStore.shared.log("WEB_SEARCH starting synthesis pass", category: "Search")
            var raw2 = ""
            var thinkDone2 = false
            // Pass only toolMsg (not historyMessages) to synthesis so the model has
            // fewer input tokens and more room to finish its <think> block + produce an answer.
            for try await token in llmService.generate(
                systemPrompt: synthesisPrompt,
                messages: [toolMsg],
                thinkingEnabled: showThinking
            ) {
                guard let i = messages.firstIndex(where: { $0.id == assistantID }) else { break }
                applyStreamToken(token, rawBuffer: &raw2, thinkDone: &thinkDone2, showThinking: showThinking, idx: i)
            }
            let synthesisPreview = String(messages.first(where: { $0.id == assistantID })?.content.prefix(ChatConstants.synthesisLogPreviewLength) ?? "")
            llmLogger.info("🔍 WEB_SEARCH synthesis done, content='\(synthesisPreview, privacy: .public)'")
            DebugLogStore.shared.log("WEB_SEARCH synthesis done: '\(synthesisPreview)'", category: "Search")
            if let i = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[i].isWebSearchResult = true
            }
        } catch is CancellationError {
            // User cancelled — leave partial content visible
        } catch {
            llmLogger.error("🔍 WEB_SEARCH failed: \(error.localizedDescription, privacy: .public)")
            DebugLogStore.shared.log("WEB_SEARCH failed: \(error.localizedDescription)", category: "Search", level: .error)
            if let i = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[i].content = "Search failed: \(error.localizedDescription)"
            }
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

    // MARK: - Session load cleanup

    /// Clears in-flight flags persisted when the app was killed mid-generation.
    private static func sanitizeStaleState(_ messages: inout [ChatMessage]) {
        for i in messages.indices where messages[i].role == .assistant {
            // Clear stuck thinking flag
            messages[i].isThinking = false

            // Web search tag present but synthesis never ran → mark interrupted
            if messages[i].isStreamingWebSearch {
                messages[i].content = "*(Search was interrupted.)*"
                messages[i].isWebSearchResult = true
            }

            // Calendar action tag present but never executed → strip the raw block
            if messages[i].isStreamingAction {
                let stripped = messages[i].content
                    .components(separatedBy: "\n")
                    .filter { !$0.contains("[CALENDAR_ACTION:") }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                messages[i].content = stripped.isEmpty ? "*(Action was interrupted.)*" : stripped
            }
        }

        // Remove dangling empty assistant messages (killed before any token was written)
        messages.removeAll {
            $0.role == .assistant
            && $0.content.isEmpty
            && $0.calendarEventPreviews.isEmpty
            && $0.calendarFreeSlots.isEmpty
        }
    }

}
