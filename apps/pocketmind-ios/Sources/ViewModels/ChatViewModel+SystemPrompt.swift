import Foundation

// MARK: - System prompt construction + calendar action dispatch
// Separated from the core ViewModel to keep each file under 300 lines.

extension ChatViewModel {

    // Matches [CALENDAR_ACTION:{...}] — uses negative lookahead \}(?!\]) so that
    // `}` characters inside JSON string values (e.g. notes, title) are allowed,
    // while still correctly terminating at the closing `}]` sequence.
    static let actionPattern = #"\[CALENDAR_ACTION:(\{(?:[^}]|\}(?!\]))*\})\]"#

    func executeCalendarActions(in text: String) async -> (content: String, previews: [CalendarEventPreview]) {
        guard let regex = try? NSRegularExpression(pattern: Self.actionPattern, options: [.dotMatchesLineSeparators]) else { return (text, []) }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return (text, []) }

        var result = text
        var previews: [CalendarEventPreview] = []
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
            case .queryResult(let answer):
                replacement = answer
            case .failure(let msg):
                replacement = msg
            }
            result = result.replacingCharacters(in: fullRange, with: replacement)
        }
        return (result, previews)
    }

    func buildSystemPrompt() async -> String {
        let today = formattedToday()
        let calendarEnabled = settings.calendarAccessEnabled && calendarService.isAuthorized
        var parts: [String] = [
            """
            You are PocketMind, an on-device AI assistant\(calendarEnabled ? " with direct read and write access to the user's iOS calendar" : "").
            Today is \(today).
            Be concise. Use plain text, no markdown.
            """,
        ]
        if calendarEnabled { parts.append(calendarToolInstructions()) }
        if calendarEnabled, let ctx = calendarContext() { parts.append(ctx) }
        return parts.joined(separator: " ")
    }

    /// The CALENDAR TOOL instruction block injected into the system prompt.
    /// Assembled from three focused helpers to keep each section under 60 lines.
    func calendarToolInstructions() -> String {
        """
            CALENDAR TOOL
            When the user wants to create, update, or delete an event, you MUST output a [CALENDAR_ACTION:...] block. The block is mandatory — without it the action does not execute.

            \(calendarBlockFormats())

            \(calendarActionExamples())

            \(calendarActionRules())
            """
    }

    /// Defines the supported [CALENDAR_ACTION:...] block formats and output structure.
    func calendarBlockFormats() -> String {
        """
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
            """
    }

    /// Few-shot examples covering all action types for in-context learning.
    func calendarActionExamples() -> String {
        """
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
            """
    }

    /// Hard rules that govern all calendar action output.
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
            - NEVER skip the block. NEVER output text-only when an action is requested.
            - NEVER tell the user to make changes manually.
            """
    }

    /// Fetches the user's calendar events for the prompt context.
    /// Returns nil if calendar access was revoked or there are no events.
    func calendarContext() -> String? {
        let windowStart = Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
        let events = calendarService.fetchEvents(from: windowStart, days: 16)
        // Sync revocation: if OS denied access between toggle and now, disable the setting.
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
