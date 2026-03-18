import Combine
import Foundation
import UIKit

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
    private var cancellables = Set<AnyCancellable>()
    // Prevents auto-submit when the user manually taps the mic button to stop recording
    private var suppressSpeechAutoSend = false

    nonisolated(unsafe) private static let historyURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chat_history.json")
    }()

    init(llmService: LLMService, calendarService: CalendarService, calendarActionController: CalendarActionController, settings: AppSettings) {
        self.llmService = llmService
        self.calendarService = calendarService
        self.calendarActionController = calendarActionController
        self.settings = settings
        self.isModelLoaded = llmService.isLoaded

        // Load persisted history asynchronously — avoids blocking the main thread on launch.
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let data = try? Data(contentsOf: ChatViewModel.historyURL),
               let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
                self.messages = saved
            }
        }

        // assign(to: &$property) uses weak self internally — no retain cycle.
        llmService.$isLoaded.assign(to: &$isModelLoaded)
        llmService.$isGenerating.assign(to: &$isGenerating)
        speechService.$isRecording.assign(to: &$isSpeechRecording)
        speechService.$isAuthorized.assign(to: &$isSpeechAvailable)

        // Forward live transcript into the input field while recording
        speechService.$transcript
            .filter { !$0.isEmpty }
            .assign(to: &$inputText)

        // Persist messages on change — debounced on MainActor, disk write offloaded to background.
        $messages
            .debounce(for: .seconds(3), scheduler: RunLoop.main)
            .sink { [weak self] msgs in
                guard self != nil else { return }
                let filtered = msgs.filter { $0.role != .system }
                Task.detached(priority: .utility) {
                    if let data = try? JSONEncoder().encode(filtered) {
                        try? data.write(to: ChatViewModel.historyURL, options: .atomic)
                    }
                }
            }
            .store(in: &cancellables)

        // Auto-submit when speech recognition ends naturally (final result / silence timeout).
        // If the user manually tapped the mic button to stop, suppressSpeechAutoSend is set
        // in toggleSpeech() and the observer skips the send.
        speechService.$isRecording
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
                Task { await self.sendMessage() }
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
                Self.impact(.light)
            } catch {
                errorMessage = "Microphone error: \(error.localizedDescription)"
            }
        }
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating, isModelLoaded else { return }

        Self.impact(.light)
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
        let historyLimit = ramGB >= 6 ? 50 : 20
        let historyMessages = Array(messages.dropLast().suffix(historyLimit))

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
            Self.notifySuccess()
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
            try calendarService.createEvent(
                title: preview.title,
                start: preview.start,
                end: preview.end,
                reminderMinutes: preview.reminderMinutes,
                isAllDay: preview.isAllDay,
                recurrence: preview.recurrence
            )
            messages[msgIdx].calendarEventPreviews[previewIdx].state = .restored
            Self.notifySuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelDeletion(messageID: UUID, previewID: UUID) {
        guard let msgIdx = messages.firstIndex(where: { $0.id == messageID }),
              let previewIdx = messages[msgIdx].calendarEventPreviews.firstIndex(where: { $0.id == previewID })
        else { return }
        messages[msgIdx].calendarEventPreviews[previewIdx].state = .deletionCancelled
        Self.impact(.light)
    }

    func confirmAllDeletions(messageID: UUID) async {
        guard let msgIdx = messages.firstIndex(where: { $0.id == messageID }) else { return }
        let indices = messages[msgIdx].calendarEventPreviews.indices.filter {
            messages[msgIdx].calendarEventPreviews[$0].state == .pendingDeletion
        }
        var failures: [String] = []
        for idx in indices {
            guard let identifier = messages[msgIdx].calendarEventPreviews[idx].eventIdentifier else {
                messages[msgIdx].calendarEventPreviews[idx].state = .deletionCancelled
                continue
            }
            do {
                try calendarService.deleteEvent(identifier: identifier)
                messages[msgIdx].calendarEventPreviews[idx].state = .deleted
            } catch {
                messages[msgIdx].calendarEventPreviews[idx].state = .deletionCancelled
                failures.append(messages[msgIdx].calendarEventPreviews[idx].title)
            }
        }
        if failures.isEmpty {
            Self.notifySuccess()
        } else {
            errorMessage = "Couldn't delete: \(failures.joined(separator: ", "))"
        }
    }

    func cancelAllDeletions(messageID: UUID) {
        guard let msgIdx = messages.firstIndex(where: { $0.id == messageID }) else { return }
        for idx in messages[msgIdx].calendarEventPreviews.indices {
            if messages[msgIdx].calendarEventPreviews[idx].state == .pendingDeletion {
                messages[msgIdx].calendarEventPreviews[idx].state = .deletionCancelled
            }
        }
        Self.impact(.light)
    }

    func confirmUpdate(messageID: UUID, previewID: UUID) async {
        guard let msgIdx = messages.firstIndex(where: { $0.id == messageID }),
              let previewIdx = messages[msgIdx].calendarEventPreviews.firstIndex(where: { $0.id == previewID }),
              let identifier = messages[msgIdx].calendarEventPreviews[previewIdx].eventIdentifier,
              let pending = messages[msgIdx].calendarEventPreviews[previewIdx].pendingUpdate
        else { return }
        do {
            let newState = try calendarService.applyUpdate(pending, to: identifier)
            // Mirror applied changes onto the preview so the card shows the updated values
            if let t = pending.title    { messages[msgIdx].calendarEventPreviews[previewIdx].title = t }
            if let s = pending.start    { messages[msgIdx].calendarEventPreviews[previewIdx].start = s }
            if let e = pending.end      { messages[msgIdx].calendarEventPreviews[previewIdx].end = e }
            if let a = pending.isAllDay { messages[msgIdx].calendarEventPreviews[previewIdx].isAllDay = a }
            if let m = pending.reminderMinutes { messages[msgIdx].calendarEventPreviews[previewIdx].reminderMinutes = m }
            messages[msgIdx].calendarEventPreviews[previewIdx].state = newState
            messages[msgIdx].calendarEventPreviews[previewIdx].pendingUpdate = nil
            Self.notifySuccess()
        } catch CalendarError.eventNotFound {
            // Event was deleted externally — dismiss the card rather than leaving it stuck.
            messages[msgIdx].calendarEventPreviews[previewIdx].state = .updateCancelled
            messages[msgIdx].calendarEventPreviews[previewIdx].pendingUpdate = nil
            errorMessage = "That event was deleted from your calendar."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelUpdate(messageID: UUID, previewID: UUID) {
        guard let msgIdx = messages.firstIndex(where: { $0.id == messageID }),
              let previewIdx = messages[msgIdx].calendarEventPreviews.firstIndex(where: { $0.id == previewID })
        else { return }
        messages[msgIdx].calendarEventPreviews[previewIdx].state = .updateCancelled
        messages[msgIdx].calendarEventPreviews[previewIdx].pendingUpdate = nil
        Self.impact(.light)
    }

    /// Receives a query from Siri and sends it as if the user typed it.
    func handleSiriQuery(_ text: String) {
        inputText = text
        Task { await sendMessage() }
    }

    func clearHistory() {
        llmService.cancelGeneration()
        messages = []
        try? FileManager.default.removeItem(at: ChatViewModel.historyURL)
    }

    /// Immediately writes current messages to disk — call when app enters background.
    func flushPersistence() {
        let filtered = messages.filter { $0.role != .system }
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(filtered) {
                try? data.write(to: ChatViewModel.historyURL, options: .atomic)
            }
        }
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
            case .bulkPending(let pending):
                replacement = ""
                previews.append(contentsOf: pending)
            case .queryResult(let answer):
                replacement = answer
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
            CALENDAR TOOL
            When the user wants to create, update, or delete an event, you MUST output a [CALENDAR_ACTION:...] block. The block is mandatory — without it the action does not execute.

            Block formats:
            Create:       [CALENDAR_ACTION:{"action":"create","title":"TITLE","start":"YYYY-MM-DDTHH:MM:SS","end":"YYYY-MM-DDTHH:MM:SS","location":"","notes":"","reminderMinutes":15}]
            Create all-day: [CALENDAR_ACTION:{"action":"create","title":"TITLE","start":"YYYY-MM-DDT00:00:00","end":"YYYY-MM-DDT00:00:00","isAllDay":true}]
            Update:       [CALENDAR_ACTION:{"action":"update","search":"CURRENT TITLE","title":"NEW TITLE","start":"YYYY-MM-DDTHH:MM:SS","end":"YYYY-MM-DDTHH:MM:SS","location":"","notes":"","reminderMinutes":15}]
            Delete one:   [CALENDAR_ACTION:{"action":"delete","search":"EXACT EVENT TITLE"}]
            Delete range: [CALENDAR_ACTION:{"action":"delete","start":"YYYY-MM-DDTHH:MM:SS","end":"YYYY-MM-DDTHH:MM:SS"}]
            Query free slots: [CALENDAR_ACTION:{"action":"query","start":"YYYY-MM-DDTHH:MM:SS","end":"YYYY-MM-DDTHH:MM:SS","durationMinutes":60}]

            Output format — block first, one short sentence after:
            [CALENDAR_ACTION:{...}]
            One sentence here.

            Example — delete request (event "Dentist" is in the calendar list):
            User: delete my dentist appointment
            You: [CALENDAR_ACTION:{"action":"delete","search":"Dentist"}]
            Deletion queued — tap Delete on the card to confirm.

            IMPORTANT for delete and update: the "search" field must be the EXACT title of the event as it appears in the calendar list below. Never invent a generic name like "Appointment" — look at the user's actual events and use the exact title.

            Example — create request:
            User: add a meeting tomorrow at 3pm
            You: [CALENDAR_ACTION:{"action":"create","title":"Meeting","start":"2026-03-18T15:00:00","end":"2026-03-18T16:00:00","location":"","notes":""}]
            Added to your calendar.

            Example — create with reminder:
            User: add dentist Friday 10am, remind me 30 minutes before
            You: [CALENDAR_ACTION:{"action":"create","title":"Dentist","start":"2026-03-20T10:00:00","end":"2026-03-20T11:00:00","reminderMinutes":30}]
            Added with a 30-minute reminder.

            Example — reschedule (move to new time):
            User: move my dentist to Friday at 2pm
            You: [CALENDAR_ACTION:{"action":"update","search":"Dentist","start":"2026-03-20T14:00:00","end":"2026-03-20T15:00:00"}]
            Rescheduled.

            Example — rename an event:
            User: rename "Team Sync" to "Weekly Review"
            You: [CALENDAR_ACTION:{"action":"update","search":"Team Sync","title":"Weekly Review"}]
            Renamed.

            Example — add notes or location to existing event (omit title/start/end if not changing them):
            User: add Zoom link to my standup
            You: [CALENDAR_ACTION:{"action":"update","search":"Standup","notes":"https://zoom.us/j/123456"}]
            Notes added.

            Example — add reminder to existing event:
            User: remind me 1 hour before my dentist appointment
            You: [CALENDAR_ACTION:{"action":"update","search":"Dentist","reminderMinutes":60}]
            Reminder set.

            Example — two actions in one message:
            User: delete dentist and add gym tomorrow at 7am
            You: [CALENDAR_ACTION:{"action":"delete","search":"Dentist"}]
            [CALENDAR_ACTION:{"action":"create","title":"Gym","start":"2026-03-18T07:00:00","end":"2026-03-18T08:00:00"}]
            Done — dentist queued for deletion, gym added.

            Example — all-day event:
            User: add a holiday on April 1
            You: [CALENDAR_ACTION:{"action":"create","title":"Holiday","start":"2026-04-01T00:00:00","end":"2026-04-01T00:00:00","isAllDay":true}]
            Added as an all-day event.

            Example — recurring event:
            User: add a weekly team standup every Monday at 9am
            You: [CALENDAR_ACTION:{"action":"create","title":"Team Standup","start":"2026-03-23T09:00:00","end":"2026-03-23T09:30:00","recurrence":"weekly"}]
            Added as a weekly recurring event.

            Example — find free slots:
            User: find a free 2-hour slot this week
            You: [CALENDAR_ACTION:{"action":"query","start":"2026-03-17T00:00:00","end":"2026-03-21T23:59:59","durationMinutes":120}]
            Here are the available windows.

            Example — delete all events in a date range:
            User: clear my schedule for next Monday
            You: [CALENDAR_ACTION:{"action":"delete","start":"2026-03-23T00:00:00","end":"2026-03-23T23:59:59"}]
            Tap Delete on each card to confirm removal.

            Rules:
            - Dates: ISO8601, no timezone. Default duration: 1 hour.
            - For update: only include the fields you want to change. Omit title if not renaming. Omit start/end if not rescheduling.
            - Delete: search must match the exact event title from the calendar list. Do NOT say it was deleted — deletion requires the user to tap the confirm button.
            - reminderMinutes: include on create or update when user explicitly asks for a reminder. Omit otherwise.
            - isAllDay: include only for all-day events (holidays, birthdays, etc). Omit start/end time precision.
            - recurrence: "daily" | "weekly" | "monthly" | "yearly". Only include when user asks for a repeating event.
            - recurrenceEnd: ISO8601 date when recurrence stops. Omit for indefinite.
            - NEVER skip the block. NEVER output text-only when an action is requested.
            - NEVER tell the user to make changes manually.
            """
        ]

        if settings.calendarAccessEnabled {
            let windowStart = Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
            let events = calendarService.fetchEvents(from: windowStart, days: 16)
            // Sync revocation: if OS denied access between the setting toggle and now, disable the toggle.
            if !calendarService.isAuthorized {
                settings.calendarAccessEnabled = false
            } else if !events.isEmpty {
                parts.append("\nUser's calendar (2 days back, 14 days ahead):\n\(events)")
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

    // MARK: - Haptics

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private static func notifySuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
