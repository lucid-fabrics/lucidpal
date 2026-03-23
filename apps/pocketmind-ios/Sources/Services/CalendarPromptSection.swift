import Foundation

// MARK: - CalendarPromptSection

/// CALENDAR TOOL instructions + live calendar context (events ±2/+14 days).
/// Returns nil when calendar access is not granted or disabled in settings.
struct CalendarPromptSection: PromptSection {
    let calendarService: any CalendarServiceProtocol
    let settings: any AppSettingsProtocol

    func build() async -> String? {
        guard settings.calendarAccessEnabled, calendarService.isAuthorized else {
            if !calendarService.isAuthorized { settings.calendarAccessEnabled = false }
            return nil
        }
        var parts = [toolInstructions()]
        if let ctx = calendarContext() { parts.append(ctx) }
        return parts.joined(separator: "\n")
    }

    // MARK: - Private helpers

    private func calendarContext() -> String? {
        let windowStart = Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
        let events = calendarService.fetchEvents(from: windowStart, days: 16)
        guard !events.isEmpty else { return nil }
        return "\nUser's calendar (2 days back, 14 days ahead):\n\(events)"
    }

    // swiftlint:disable line_length
    private func toolInstructions() -> String {
        """
            CALENDAR TOOL
            When the user wants to create, update, or delete an event, you MUST output a [CALENDAR_ACTION:...] block. The block is mandatory — without it the action does not execute.

            \(blockFormats())

            \(actionExamples())

            \(actionRules())
            """
    }
    // swiftlint:enable line_length

    // swiftlint:disable line_length
    private func blockFormats() -> String {
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
    // swiftlint:enable line_length

    private func actionExamples() -> String {
        [createExamples(), updateDeleteExamples(), queryExamples()].joined(separator: "\n\n")
    }

    // swiftlint:disable:next function_body_length
    private func createExamples() -> String {
        """
            Example — NOT a calendar request (desire/intention, no scheduling language):
            User: I would like to eat pizza tonight.
            You: That sounds great! Enjoy your pizza.

            Example — NOT a calendar request (statement about the future):
            User: I'm going to go for a run later.
            You: Nice! Staying active is always a good idea.

            Example — NOT a calendar request ("remind me" for factual recall, not time-based):
            User: Remind me how recursion works.
            You: Recursion is when a function calls itself with a smaller input until it hits a base case.

            Example — NOT a calendar request ("book" as noun, not scheduling verb):
            User: Can you recommend a good book?
            You: Depends on the genre — what do you usually enjoy?

            Example — NOT a calendar request ("set up" for non-event):
            User: How do I set up SSH keys?
            You: Run `ssh-keygen -t ed25519`, then copy the public key to your server's `~/.ssh/authorized_keys`.

            Example — NOT a calendar request ("schedule" as noun):
            User: What's the TV schedule tonight?
            You: I don't have live TV listings — check your provider's app or a site like TVGuide.

            Example — NOT a calendar request ("clear" in non-scheduling context):
            User: Can you clear up the confusion about async/await?
            You: Sure — async/await is syntactic sugar over Promises that lets you write asynchronous code that reads like synchronous code.

            Example — missing time (date is known, time is not):
            User: add a meeting tomorrow
            You: What time?

            Example — missing date and time:
            User: schedule a dentist appointment
            You: What date and time?

            Example — missing everything:
            User: schedule something
            You: What's the event, date, and time?

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

    // swiftlint:disable line_length
    private func updateDeleteExamples() -> String {
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
    // swiftlint:enable line_length

    private func queryExamples() -> String {
        """
            Example — list events in a date range:
            User: what's on my calendar this week?
            You: [CALENDAR_ACTION:{"action":"list","start":"2026-03-18T00:00:00","end":"2026-03-22T23:59:59"}]
            Here's your week.

            Example — list events for today:
            User: what do I have on my calendar today?
            You: [CALENDAR_ACTION:{"action":"list","start":"2026-03-22T00:00:00","end":"2026-03-22T23:59:59"}]
            Here's today.

            Example — list events (busy check):
            User: am I busy tomorrow?
            You: [CALENDAR_ACTION:{"action":"list","start":"2026-03-23T00:00:00","end":"2026-03-23T23:59:59"}]
            Here's tomorrow.

            Example — NOT a calendar request ("what do I have" for food/tasks, not schedule):
            User: what do I have for dinner?
            You: I don't have access to your fridge — what ingredients do you have in mind?

            Example — NOT a calendar request (general/philosophical question):
            User: What's the purpose of life?
            You: That's a classic philosophical question. Many traditions offer different answers — meaning, happiness, connection, or simply being present.

            Example — NOT a calendar request ("plan" as general advice):
            User: What should I plan this week?
            You: Depends on your goals — want to focus on work, health, or something else?

            Example — find free slots:
            User: find a free 2-hour slot this week
            You: [CALENDAR_ACTION:{"action":"query","start":"2026-03-17T00:00:00","end":"2026-03-21T23:59:59","durationMinutes":120}]
            Checked your week.
            """
    }

    // swiftlint:disable line_length
    private func actionRules() -> String {
        """
            Rules:
            - Calendar intent detection: Only emit [CALENDAR_ACTION] when the user explicitly uses scheduling language directed at their personal calendar — "add [event]", "schedule [event]", "book [an appointment/slot]", "block time", "put on my calendar", "set up [a meeting/event]", "create an event", "remind me [at/before/X minutes before]". Narrow qualifiers matter: "book" as a noun (book recommendation), "set up" for non-events (set up my laptop), "schedule" as a noun (TV schedule, bus schedule), and "remind me" for factual recall ("remind me how X works") are NOT calendar requests.
            - NEVER proactively show or summarize the user's calendar unless they explicitly ask about their calendar, schedule, or events. If the question is philosophical, general knowledge, a coding question, or unrelated to scheduling, ignore the calendar context entirely and answer directly. Do NOT default to showing today's schedule for unrelated questions.
            - "What do I have [for dinner / to eat / left to do / in my fridge]?" is NOT a calendar query — only "what do I have [today/tomorrow/this week] on my calendar?" is.
            - "Am I busy [day]?" and "Do I have anything [day]?" ARE calendar queries — emit CALENDAR_ACTION:list for that day.
            - "What should I plan / do this week?" is a general advice question, NOT a prompt to list calendar events.
            - Dates: ISO8601, no timezone. Default duration: 1 hour.
            - For update: only include the fields you want to change. Omit title if not renaming. Omit start/end if not rescheduling.
            - Delete: search must match the exact event title from the calendar list. Do NOT say it was deleted — deletion requires the user to tap the confirm button.
            - reminderMinutes: include on create or update when user explicitly asks for a reminder. Omit otherwise.
            - isAllDay: include only for all-day events (holidays, birthdays, etc). Omit start/end time precision.
            - recurrence: "daily" | "weekly" | "monthly" | "yearly". Only include when user asks for a repeating event.
            - recurrenceEnd: ISO8601 date when recurrence stops. Omit for indefinite.
            - Clarification before acting: Before emitting any create block you MUST have an explicit date AND time. If either is missing, ask for them together in one short question ("What date and time?"). Never guess a time from context words like "evening", "later", "tonight" — always ask. Title may be inferred from the conversation if unambiguous (e.g. "schedule my dentist" → title "Dentist"); otherwise ask "What should I call it?".
            - NEVER skip the block when you have enough info. NEVER output text-only when an action is requested and all required fields are known.
            - NEVER tell the user to make changes manually.
            - Conflict: if the system appends a conflict note (e.g. "Heads-up: overlaps with..."), acknowledge it naturally in your response and tell the user they can tap the card to keep, cancel, or reschedule to a free slot.
            - list: use to show events in a date range when the user asks "what's on my calendar", "show my meetings", etc. Do NOT use query for listing — query is only for finding free slots.
            - NEVER enumerate events in prose when using a list or query action. The app renders the events in a card widget. Output ONLY the [CALENDAR_ACTION] block + one short sentence that directly answers the user's question (e.g. a recommendation, a count, or a summary). Do not bullet-list event titles or times.
            """
    }
    // swiftlint:enable line_length
}
