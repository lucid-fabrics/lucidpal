import Combine
import Foundation

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

    private let llmService: LLMService
    private let calendarService: CalendarService
    private let calendarActionController: CalendarActionController
    private let settings: AppSettings
    private let speechService = SpeechService()

    init(llmService: LLMService, calendarService: CalendarService, calendarActionController: CalendarActionController, settings: AppSettings) {
        self.llmService = llmService
        self.calendarService = calendarService
        self.calendarActionController = calendarActionController
        self.settings = settings
        self.isModelLoaded = llmService.isLoaded

        // assign(to: &$property) uses weak self internally — no retain cycle.
        llmService.$isLoaded.assign(to: &$isModelLoaded)
        llmService.$isGenerating.assign(to: &$isGenerating)
        speechService.$isRecording.assign(to: &$isSpeechRecording)
        speechService.$isAuthorized.assign(to: &$isSpeechAvailable)

        // Forward live transcript into the input field while recording
        speechService.$transcript
            .filter { !$0.isEmpty }
            .assign(to: &$inputText)

        // Request speech permissions on launch
        Task { await speechService.requestAuthorization() }
    }

    func toggleSpeech() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            do {
                try speechService.startRecording()
            } catch {
                errorMessage = "Microphone error: \(error.localizedDescription)"
            }
        }
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating, isModelLoaded else { return }

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

        // Snapshot history without the empty assistant placeholder
        let historyMessages = Array(messages.dropLast())

        do {
            var raw = ""           // full accumulated raw output
            var thinkDone = false  // have we seen </think> yet?
            let showThinking = settings.thinkingEnabled  // snapshot at send time

            for try await token in llmService.generate(systemPrompt: systemPrompt, messages: historyMessages, thinkingEnabled: showThinking) {
                guard let idx = messages.firstIndex(where: { $0.id == assistantID }) else { break }
                raw += token

                if thinkDone {
                    messages[idx].content += token
                } else if raw.hasPrefix("<think>") {
                    if let closeRange = raw.range(of: "</think>") {
                        let thinkText = String(raw[raw.index(raw.startIndex, offsetBy: "<think>".count) ..< closeRange.lowerBound])
                        let response  = String(raw[closeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if showThinking {
                            messages[idx].thinkingContent = thinkText.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        messages[idx].isThinking = false
                        messages[idx].content = response
                        thinkDone = true
                    } else {
                        // Still inside <think>
                        if showThinking {
                            messages[idx].isThinking = true
                            messages[idx].thinkingContent = String(raw.dropFirst("<think>".count))
                        }
                        // When thinking is off: buffer silently, show nothing
                    }
                } else if "<think>".hasPrefix(raw) {
                    // Still buffering opening tag — don't display yet
                } else {
                    thinkDone = true
                    messages[idx].content = raw
                }
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

    // MARK: - Calendar deletion confirmation

    func confirmDeletion(messageID: UUID, previewID: UUID) async {
        guard let msgIdx = messages.firstIndex(where: { $0.id == messageID }),
              let previewIdx = messages[msgIdx].calendarEventPreviews.firstIndex(where: { $0.id == previewID }),
              let identifier = messages[msgIdx].calendarEventPreviews[previewIdx].eventIdentifier
        else { return }
        do {
            try calendarService.deleteEvent(identifier: identifier)
            messages[msgIdx].calendarEventPreviews[previewIdx].state = .deleted
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func undoDeletion(messageID: UUID, previewID: UUID) async {
        guard let msgIdx = messages.firstIndex(where: { $0.id == messageID }),
              let previewIdx = messages[msgIdx].calendarEventPreviews.firstIndex(where: { $0.id == previewID })
        else { return }
        let preview = messages[msgIdx].calendarEventPreviews[previewIdx]
        do {
            try calendarService.createEvent(title: preview.title, start: preview.start, end: preview.end, location: nil, notes: nil)
            messages[msgIdx].calendarEventPreviews[previewIdx].state = .restored
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelDeletion(messageID: UUID, previewID: UUID) {
        guard let msgIdx = messages.firstIndex(where: { $0.id == messageID }),
              let previewIdx = messages[msgIdx].calendarEventPreviews.firstIndex(where: { $0.id == previewID })
        else { return }
        messages[msgIdx].calendarEventPreviews[previewIdx].state = .deletionCancelled
    }

    /// Receives a query from Siri and sends it as if the user typed it.
    func handleSiriQuery(_ text: String) {
        inputText = text
        Task { await sendMessage() }
    }

    func clearHistory() {
        llmService.cancelGeneration()
        messages = []
    }

    // MARK: - Calendar action dispatch

    // Matches [CALENDAR_ACTION:{...}] — uses negative lookahead \}(?!\]) so that
    // `}` characters inside JSON string values (e.g. notes, title) are allowed,
    // while still correctly terminating at the closing `}]` sequence.
    private static let actionPattern = #"\[CALENDAR_ACTION:(\{(?:[^}]|\}(?!\]))*\})\]"#

    private func executeCalendarActions(in text: String) async -> (content: String, previews: [CalendarEventPreview]) {
        guard let regex = try? NSRegularExpression(pattern: Self.actionPattern, options: [.dotMatchesLineSeparators]) else { return (text, []) }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return (text, []) }

        var result = text
        var previews: [CalendarEventPreview] = []
        for match in matches.reversed() {
            let fullRange = Range(match.range, in: result)!
            let jsonRange = Range(match.range(at: 1), in: result)!
            let json = String(result[jsonRange])

            let actionResult = await calendarActionController.execute(json: json)
            let replacement: String
            switch actionResult {
            case .success(let msg, let preview):
                replacement = msg
                previews.append(preview)
            case .failure(let msg):
                replacement = msg
            }
            result = result.replacingCharacters(in: fullRange, with: replacement)
        }
        return (result, previews)
    }

    private func buildSystemPrompt() async -> String {
        let today = formattedToday()
        var parts: [String] = [
            """
            You are PocketMind, an on-device AI assistant with direct read and write access to the user's iOS calendar.
            Today is \(today).
            Be concise. Use plain text, no markdown.
            """,
            """
            CALENDAR TOOL — output exactly one block per action, then one sentence. Do NOT include any label before the block.
            To create: [CALENDAR_ACTION:{"action":"create","title":"TITLE","start":"YYYY-MM-DDTHH:MM:SS","end":"YYYY-MM-DDTHH:MM:SS","location":"","notes":""}]
            To update: [CALENDAR_ACTION:{"action":"update","search":"EXISTING TITLE","title":"NEW TITLE","start":"YYYY-MM-DDTHH:MM:SS","end":"YYYY-MM-DDTHH:MM:SS","location":"","notes":""}]
            To delete: [CALENDAR_ACTION:{"action":"delete","search":"EXISTING TITLE"}]
            Rules:
            - Dates: ISO8601, no timezone (e.g. 2026-03-18T14:00:00). Default duration: 1 hour.
            - For update: set action to "update", search to the current title, title to the new title.
            - For delete: set action to "delete", search to the exact event title. IMPORTANT: deletion requires user confirmation — say "I've sent a deletion request. Tap Delete to confirm." Do NOT say the event was deleted.
            - For create: after the block say "Added to your calendar."
            - NEVER output a label like "Delete:" or "Create:" before the block.
            - NEVER skip the block when a create, update, or delete is requested.
            - NEVER tell the user to make changes manually.
            """
        ]

        if settings.calendarAccessEnabled {
            let events = calendarService.fetchEvents(from: .now, days: 7)
            // Sync revocation: if OS denied access between the setting toggle and now, disable the toggle.
            if !calendarService.isAuthorized {
                settings.calendarAccessEnabled = false
            } else if !events.isEmpty {
                parts.append("\nUser's upcoming events (next 7 days):\n\(events)")
            }
        }

        return parts.joined(separator: " ")
    }

    private func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: .now)
    }
}
