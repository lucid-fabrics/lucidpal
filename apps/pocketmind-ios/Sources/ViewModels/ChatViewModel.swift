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

    @Published var suggestedPrompts: [String] = []
    @Published var isGeneratingSuggestions = false

    /// Navigation title — equals session title in session mode, "PocketMind" otherwise.
    @Published private(set) var sessionTitle: String

    let llmService: any LLMServiceProtocol
    let calendarService: any CalendarServiceProtocol
    let calendarActionController: any CalendarActionControllerProtocol
    let settings: any AppSettingsProtocol
    let speechService: any SpeechServiceProtocol
    let hapticService: any HapticServiceProtocol
    let history: any ChatHistoryManagerProtocol
    var cancellables = Set<AnyCancellable>()
    // Prevents auto-submit when the user manually taps the mic button to stop recording
    var suppressSpeechAutoSend = false
    // Set to true when voice auto-start triggered recording — preserves auto-send on manual stop
    var voiceAutoStartActive = false

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
        calendarActionController: any CalendarActionControllerProtocol,
        settings: any AppSettingsProtocol,
        speechService: any SpeechServiceProtocol,
        hapticService: any HapticServiceProtocol,
        historyManager: any ChatHistoryManagerProtocol,
        // Session-mode params — pass these to enable multi-session persistence.
        session: ChatSession? = nil,
        sessionManager: (any SessionManagerProtocol)? = nil,
        onSessionUpdated: ((@MainActor (ChatSessionMeta) -> Void))? = nil,
        pendingInput: String? = nil
    ) {
        self.llmService = llmService
        self.calendarService = calendarService
        self.calendarActionController = calendarActionController
        self.settings = settings
        self.speechService = speechService
        self.hapticService = hapticService
        self.history = session != nil ? NoOpChatHistoryManager() : historyManager
        self.sessionID = session?.id
        self.sessionCreatedAt = session?.createdAt ?? .now
        self.sessionManager = sessionManager
        self.onSessionUpdated = onSessionUpdated
        self.sessionTitle = session?.title ?? "PocketMind"
        self.pendingInput = pendingInput
        self.isModelLoaded = llmService.isLoaded

        // Load messages: from session if in session mode, else from history file.
        self.messages = session?.messages ?? historyManager.load()

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

        // Forward live transcript into the input field while recording
        speechService.transcriptPublisher
            .filter { !$0.isEmpty }
            .sink { [weak self] in self?.inputText = $0 }
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
                if self.suppressSpeechAutoSend {
                    self.suppressSpeechAutoSend = false
                    return
                }
                guard self.settings.speechAutoSendEnabled else { return }
                guard !self.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task { [weak self] in await self?.sendMessage() }
            }
            .store(in: &cancellables)

        // Request speech permissions on launch
        Task { [weak self] in await self?.speechService.requestAuthorization() }

        // If model is already loaded and there's nothing to show, kick off suggestions.
        if llmService.isLoaded && messages.isEmpty && pendingInput == nil {
            Task { [weak self] in await self?.generateSuggestedPrompts() }
        }
    }

    func toggleSpeech() {
        if speechService.isRecording {
            // Manual stop — suppress auto-send unless voice auto-start triggered the session
            if !voiceAutoStartActive {
                suppressSpeechAutoSend = true
            }
            voiceAutoStartActive = false
            speechService.stopRecording()
        } else {
            do {
                try speechService.startRecording()
                hapticService.impact(.light)
            } catch {
                errorMessage = "Microphone error: \(error.localizedDescription)"
            }
        }
    }

    func sendMessage() async {
        cancelSuggestionsGeneration()
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating, isModelLoaded else { return }

        hapticService.impact(.light)
        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))

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
        let systemPrompt = await buildSystemPrompt()

        let assistantMsg = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMsg)
        let assistantID = assistantMsg.id  // Capture ID — safe against clearHistory() mid-stream

        // Snapshot history without the empty assistant placeholder.
        // Cap based on device RAM: 8 K context devices get more history (50 msgs ≈ 5000 tokens),
        // 4 K context devices use 20 msgs ≈ 2000 tokens, leaving headroom for system prompt + reply.
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / ChatConstants.bytesPerGB)
        let historyLimit = ramGB >= ChatConstants.largeContextRAMThresholdGB ? ChatConstants.largeHistoryLimit : ChatConstants.smallHistoryLimit
        let historyMessages = Array(messages.dropLast().suffix(historyLimit))

        do {
            var raw = ""           // full accumulated raw output
            var thinkDone = false  // have we seen </think> yet?
            let showThinking = settings.thinkingEnabled  // snapshot at send time

            for try await token in llmService.generate(systemPrompt: systemPrompt, messages: historyMessages, thinkingEnabled: showThinking) {
                guard let idx = messages.firstIndex(where: { $0.id == assistantID }) else { break }
                applyStreamToken(token, rawBuffer: &raw, thinkDone: &thinkDone, showThinking: showThinking, idx: idx)
            }
        // Log raw LLM output for debugging
        if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
            llmLogger.info("📤 USER: \(text, privacy: .public)")
            llmLogger.info("🤖 RAW_LLM: \(self.messages[idx].content, privacy: .public)")
        }
        } catch is CancellationError {
            // User cancelled — leave partial content visible
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx].content = "Error: \(error.localizedDescription)"
            }
            errorMessage = error.localizedDescription
        }

        // After streaming, execute calendar actions (thinking already extracted live)
        if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
            messages[idx].isThinking = false
            let (content, previews, freeSlots) = await executeCalendarActions(in: messages[idx].content)
            messages[idx].content = content
            messages[idx].calendarEventPreviews = previews
            messages[idx].calendarFreeSlots = freeSlots
            llmLogger.info("✅ FINAL: \(content, privacy: .public) | events=\(previews.count) slots=\(freeSlots.count)")
        }
    }

    func cancelGeneration() {
        llmService.cancelGeneration()
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

}
