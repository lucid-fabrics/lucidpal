import Foundation
import OSLog

private let systemPromptLogger = Logger(subsystem: "app.pocketmind", category: "Chat")

// MARK: - Protocol

/// Single Responsibility: owns all LLM system-prompt generation and calendar action dispatch.
/// ChatViewModel delegates here so it does not need to change when prompt logic evolves.
@MainActor
protocol SystemPromptBuilderProtocol {
    func buildSystemPrompt() async -> String
    func executeCalendarActions(in text: String) async -> (content: String, previews: [CalendarEventPreview], freeSlots: [CalendarFreeSlot])
}

// MARK: - Implementation

@MainActor
final class SystemPromptBuilder: SystemPromptBuilderProtocol {

    private let calendarService: any CalendarServiceProtocol
    private let contextService: any ContextServiceProtocol
    private let settings: any AppSettingsProtocol
    private let calendarActionController: any CalendarActionControllerProtocol

    // Matches [CALENDAR_ACTION:{...}] — negative lookahead \}(?!\]) allows `}` inside JSON string values.
    static let actionPattern = #"\[CALENDAR_ACTION:(\{(?:[^}]|\}(?!\]))*\})\]"#

    private static let calendarActionRegex: NSRegularExpression = {
        guard let regex = try? NSRegularExpression(
            pattern: actionPattern,
            options: [.dotMatchesLineSeparators]
        ) else { // safe: pattern is a compile-time constant; failure caught by preconditionFailure
            preconditionFailure("Invalid calendarActionRegex pattern: \(actionPattern)")
        }
        return regex
    }()

    init(
        calendarService: any CalendarServiceProtocol,
        contextService: any ContextServiceProtocol,
        settings: any AppSettingsProtocol,
        calendarActionController: any CalendarActionControllerProtocol
    ) {
        self.calendarService = calendarService
        self.contextService = contextService
        self.settings = settings
        self.calendarActionController = calendarActionController
    }

    // MARK: - SystemPromptBuilderProtocol

    func executeCalendarActions(in text: String) async -> (content: String, previews: [CalendarEventPreview], freeSlots: [CalendarFreeSlot]) {
        let regex = Self.calendarActionRegex
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return (text, [], []) }

        var result = text
        var previews: [CalendarEventPreview] = []
        var freeSlots: [CalendarFreeSlot] = []
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let jsonRange = Range(match.range(at: 1), in: result) else { continue }
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
            case .queryResult(let slots):
                replacement = slots.isEmpty ? "No free slots found in that window." : ""
                freeSlots.append(contentsOf: slots)
            case .listResult(let eventPreviews):
                replacement = eventPreviews.isEmpty ? "No events found in that range." : ""
                previews.append(contentsOf: eventPreviews)
            case .failure(let msg):
                replacement = msg
            }
            result = result.replacingCharacters(in: fullRange, with: replacement)
        }
        return (result, previews, freeSlots)
    }

    func buildSystemPrompt() async -> String {
        let today = formattedToday()
        let calendarEnabled = settings.calendarAccessEnabled && calendarService.isAuthorized
        let contextEnabled = settings.notesAccessEnabled || settings.remindersAccessEnabled || settings.mailAccessEnabled
        var parts: [String] = [
            """
            You are PocketMind, an on-device AI assistant\(calendarEnabled ? " with direct read and write access to the user's iOS calendar" : "")\(contextEnabled ? " with access to the user's Notes, Reminders, and Mail" : "").
            Today is \(today).
            Be concise. Use markdown for emphasis (**bold**), bullet lists (- item), and inline code (`code`). Keep responses short.
            """,
        ]
        if calendarEnabled { parts.append(calendarToolInstructions()) }
        if calendarEnabled, let ctx = calendarContext() { parts.append(ctx) }
        if contextEnabled, let cross = await crossAppContext() { parts.append(cross) }
        let prompt = parts.joined(separator: " ")
        systemPromptLogger.info("🧠 SYSTEM_PROMPT: \(prompt, privacy: .public)")
        return prompt
    }

    // MARK: - Private helpers

    private func crossAppContext() async -> String? {
        await contextService.fetchContext(query: nil)
    }

    func calendarToolInstructions() -> String {
        """
            CALENDAR TOOL
            When the user wants to create, update, or delete an event, you MUST output a [CALENDAR_ACTION:...] block. The block is mandatory — without it the action does not execute.

            \(calendarBlockFormats())

            \(calendarActionExamples())

            \(calendarActionRules())
            """
    }

    func calendarBlockFormats() -> String {
        """
            Block formats:
            Create:       [CALENDAR_ACTION:{"action":"create","title":"TITLE","start":"YYYY-MM-DDTHH:MM:SS","end":"YYYY-MM-DDTHH:MM:SS","location":"","notes":"","reminderMinutes":15}]
            Create all-day: [CALENDAR_ACTION:{"action":"create","title":"TITLE","start":"YYYY-MM-DDT00:00:00","end":"YYYY-MM-DDT00:00:00","isAllDay":true}]
            Update:       [CALENDAR_ACTION:{"action":"update","search":"CURRENT TITLE","title":"NEW TITLE","start":"YYYY-MM-DDTHH:MM:SS","end":"YYYY-MM-DDTHH:MM:SS","location":"","notes":"","reminderMinutes":15}]
            Delete one:   [CALENDAR_ACTION:{"action":"delete","search":"EXACT EVENT TITLE"}]
            Delete range: [CALENDAR_ACTION:{"action":"delete","start":"YYYY-MM-DDTHH:MM:SS","end":"YYYY-MM-DDTHH:MM:SS"}]
            List events:  [CALENDAR_ACTION:{"action":"list","start":"YYYY-MM-DDTHH:MM:SS","end":"YYYY-MM-DDTHH:MM:SS"}]
            Query free slots: [CALENDAR_ACTION:{"action":"query","start":"YYYY-MM-DDTHH:MM:SS","end":"YYYY-MM-DDTHH:MM:SS","durationMinutes":60}]

            Output format — block first, one short sentence after:
            [CALENDAR_ACTION:{...}]
            One sentence here.
            """
    }

    private func calendarActionExamples() -> String {
        [calendarCreateExamples(), calendarUpdateDeleteExamples(), calendarQueryExamples()]
            .joined(separator: "\n\n")
    }

    private func calendarCreateExamples() -> String {
        """
            Example — ambiguous request, missing time:
            User: add a meeting tomorrow
            You: What time?

            Example — ambiguous request, missing title and time:
            User: schedule something next week
            You: What's the event and when?

            Example — create request (no conflict):
            User: add a meeting tomorrow at 3pm
            You: [CALENDAR_ACTION:{"action":"create","title":"Meeting","start":"2026-03-18T15:00:00","end":"2026-03-18T16:00:00","location":"","notes":""}]
            Added to your calendar.

            Example — create with conflict (system detects overlap after the block executes):
            User: add lunch tomorrow at noon
            You: [CALENDAR_ACTION:{"action":"create","title":"Lunch","start":"2026-03-18T12:00:00","end":"2026-03-18T13:00:00"}]
            Added — heads-up, it overlaps with "Team Meeting" (12–1 pm). Tap the card to keep it, cancel it, or find a free slot.

            Example — create with reminder:
            User: add dentist Friday 10am, remind me 30 minutes before
            You: [CALENDAR_ACTION:{"action":"create","title":"Dentist","start":"2026-03-20T10:00:00","end":"2026-03-20T11:00:00","reminderMinutes":30}]
            Added with a 30-minute reminder.

            Example — all-day event:
            User: add a holiday on April 1
            You: [CALENDAR_ACTION:{"action":"create","title":"Holiday","start":"2026-04-01T00:00:00","end":"2026-04-01T00:00:00","isAllDay":true}]
            Added as an all-day event.

            Example — recurring event:
            User: add a weekly team standup every Monday at 9am
            You: [CALENDAR_ACTION:{"action":"create","title":"Team Standup","start":"2026-03-23T09:00:00","end":"2026-03-23T09:30:00","recurrence":"weekly"}]
            Added as a weekly recurring event.
            """
    }

    private func calendarUpdateDeleteExamples() -> String {
        """
            Example — delete request (event "Dentist" is in the calendar list):
            User: delete my dentist appointment
            You: [CALENDAR_ACTION:{"action":"delete","search":"Dentist"}]
            Deletion queued — tap Delete on the card to confirm.

            IMPORTANT for delete and update: the "search" field must be the EXACT title of the event as it appears in the calendar list below. Never invent a generic name like "Appointment" — look at the user's actual events and use the exact title.

            Example — delete all events in a date range:
            User: clear my schedule for next Monday
            You: [CALENDAR_ACTION:{"action":"delete","start":"2026-03-23T00:00:00","end":"2026-03-23T23:59:59"}]
            Tap Delete on each card to confirm removal.

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
            """
    }

    private func calendarQueryExamples() -> String {
        """
            Example — list events in a date range:
            User: what's on my calendar this week?
            You: [CALENDAR_ACTION:{"action":"list","start":"2026-03-18T00:00:00","end":"2026-03-22T23:59:59"}]
            Here's your week.

            Example — answer a question about events (the app renders them; do NOT re-list in text):
            User: who is the best date for this month?
            You: [CALENDAR_ACTION:{"action":"list","start":"2026-03-01T00:00:00","end":"2026-03-31T23:59:59"}]
            March 20 and March 29 stand out — birthdays and fewer conflicts.

            Example — find free slots:
            User: find a free 2-hour slot this week
            You: [CALENDAR_ACTION:{"action":"query","start":"2026-03-17T00:00:00","end":"2026-03-21T23:59:59","durationMinutes":120}]
            Checked your week.
            """
    }

    func calendarActionRules() -> String {
        """
            Rules:
            - Dates: ISO8601, no timezone. Default duration: 1 hour.
            - For update: only include the fields you want to change. Omit title if not renaming. Omit start/end if not rescheduling.
            - Delete: search must match the exact event title from the calendar list. Do NOT say it was deleted — deletion requires the user to tap the confirm button.
            - reminderMinutes: include on create or update when user explicitly asks for a reminder. Omit otherwise.
            - isAllDay: include only for all-day events (holidays, birthdays, etc). Omit start/end time precision.
            - recurrence: "daily" | "weekly" | "monthly" | "yearly". Only include when user asks for a repeating event.
            - recurrenceEnd: ISO8601 date when recurrence stops. Omit for indefinite.
            - Clarification before acting: If a create/update request is missing critical details, ask ONE short question before emitting the block. Missing title → ask "What should I call it?". Missing time with no qualifier → ask "What time?". Do NOT guess a time when none is given. Time qualifiers you may infer: "morning" = 9am, "afternoon" = 2pm, "evening" = 6pm, "noon" = 12pm, "lunch" = 12pm. If the date is also missing, ask for date and time together in one question.
            - NEVER skip the block when you have enough info. NEVER output text-only when an action is requested and all required fields are known.
            - NEVER tell the user to make changes manually.
            - Conflict: if the system appends a conflict note (e.g. "Heads-up: overlaps with..."), acknowledge it naturally in your response and tell the user they can tap the card to keep, cancel, or reschedule to a free slot.
            - list: use to show events in a date range when the user asks "what's on my calendar", "show my meetings", etc. Do NOT use query for listing — query is only for finding free slots.
            - NEVER enumerate events in prose when using a list or query action. The app renders the events in a card widget. Output ONLY the [CALENDAR_ACTION] block + one short sentence that directly answers the user's question (e.g. a recommendation, a count, or a summary). Do not bullet-list event titles or times.
            """
    }

    private func calendarContext() -> String? {
        let windowStart = Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
        let events = calendarService.fetchEvents(from: windowStart, days: 16)
        guard calendarService.isAuthorized else {
            settings.calendarAccessEnabled = false
            return nil
        }
        guard !events.isEmpty else { return nil }
        return "\nUser's calendar (2 days back, 14 days ahead):\n\(events)"
    }

    func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: .now)
    }
}
