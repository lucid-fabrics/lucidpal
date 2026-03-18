import Combine
import Foundation

// MARK: - Constants

private enum ChatConstants {
    /// RAM threshold (GB) for selecting higher history/context limits.
    static let largeContextRAMThresholdGB = 6
    /// Max messages fed into the prompt on high-RAM devices.
    static let largeHistoryLimit = 50
    /// Max messages fed into the prompt on low-RAM devices.
    static let smallHistoryLimit = 20
    /// Seconds to debounce before persisting messages to disk.
    static let persistenceDebounceSeconds: Double = 3
    /// Seconds before auto-dismissing the error banner.
    static let errorAutoDismissSeconds: Double = 5
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published private(set) var isGenerating = false
    @Published private(set) var isPreparing = false
    @Published private(set) var isModelLoaded = false
    @Published var errorMessage: String?

    @Published private(set) var isSpeechRecording = false
    @Published private(set) var isSpeechAvailable = false

    let llmService: any LLMServiceProtocol
    let calendarService: any CalendarServiceProtocol
    let calendarActionController: any CalendarActionControllerProtocol
    let settings: AppSettings
    let speechService: any SpeechServiceProtocol
    let history: any ChatHistoryManagerProtocol
    var cancellables = Set<AnyCancellable>()
    // Prevents auto-submit when the user manually taps the mic button to stop recording
    var suppressSpeechAutoSend = false

    init(
        llmService: any LLMServiceProtocol,
        calendarService: any CalendarServiceProtocol,
        calendarActionController: any CalendarActionControllerProtocol,
        settings: AppSettings,
        speechService: any SpeechServiceProtocol,
        historyManager: any ChatHistoryManagerProtocol = ChatHistoryManager()
    ) {
        self.llmService = llmService
        self.calendarService = calendarService
        self.calendarActionController = calendarActionController
        self.settings = settings
        self.speechService = speechService
        self.history = historyManager
        self.isModelLoaded = llmService.isLoaded

        // Load persisted history asynchronously — avoids blocking the main thread on launch.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.messages = self.history.load()
        }

        // Publishers — sink used instead of assign(to:) because existentials can't project @Published.
        llmService.isLoadedPublisher
            .sink { [weak self] in self?.isModelLoaded = $0 }
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

        // Forward live transcript into the input field while recording
        speechService.transcriptPublisher
            .filter { !$0.isEmpty }
            .sink { [weak self] in self?.inputText = $0 }
            .store(in: &cancellables)

        // Persist messages on change — debounced on MainActor, disk write offloaded to background.
        $messages
            .debounce(for: .seconds(ChatConstants.persistenceDebounceSeconds), scheduler: RunLoop.main)
            .sink { [weak self] msgs in self?.history.save(msgs) }
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
        Task { await speechService.requestAuthorization() }
    }

    func toggleSpeech() {
        if speechService.isRecording {
            // Manual stop — don't auto-submit; user controls sending themselves
            suppressSpeechAutoSend = true
            speechService.stopRecording()
        } else {
            do {
                try speechService.startRecording()
                HapticService.impact(.light)
            } catch {
                errorMessage = "Microphone error: \(error.localizedDescription)"
            }
        }
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating, isModelLoaded else { return }

        HapticService.impact(.light)
        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))
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
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
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
            let (content, previews) = await executeCalendarActions(in: messages[idx].content)
            messages[idx].content = content
            messages[idx].calendarEventPreviews = previews
        }
    }

    func cancelGeneration() {
        llmService.cancelGeneration()
    }

    /// Receives a query from Siri and sends it as if the user typed it.
    func handleSiriQuery(_ text: String) {
        inputText = text
        Task { await sendMessage() }
    }

    func clearHistory() {
        llmService.cancelGeneration()
        messages = []
        history.clear()
    }

    /// Immediately writes current messages to disk — call when app enters background.
    func flushPersistence() {
        history.save(messages)
    }

    // MARK: - Token streaming

    /// Applies one streamed token to the assistant message at `idx`, handling
    /// the <think>...</think> wrapper that Qwen3 emits before its response.
    func applyStreamToken(
        _ token: String,
        rawBuffer: inout String,
        thinkDone: inout Bool,
        showThinking: Bool,
        idx: Int
    ) {
        rawBuffer += token
        if thinkDone {
            messages[idx].content += token
        } else if rawBuffer.hasPrefix("<think>") {
            if let closeRange = rawBuffer.range(of: "</think>") {
                let thinkText = String(rawBuffer[rawBuffer.index(rawBuffer.startIndex, offsetBy: "<think>".count) ..< closeRange.lowerBound])
                let response  = String(rawBuffer[closeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if showThinking {
                    messages[idx].thinkingContent = thinkText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                messages[idx].isThinking = false
                messages[idx].content = response
                thinkDone = true
            } else {
                // Still inside <think> — buffer or show depending on setting
                if showThinking {
                    messages[idx].isThinking = true
                    messages[idx].thinkingContent = String(rawBuffer.dropFirst("<think>".count))
                }
            }
        } else if "<think>".hasPrefix(rawBuffer) {
            // Still buffering opening tag — don't display yet
        } else {
            thinkDone = true
            messages[idx].content = rawBuffer
        }
    }
}
