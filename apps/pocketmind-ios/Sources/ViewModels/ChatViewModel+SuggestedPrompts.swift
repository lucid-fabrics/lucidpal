import Foundation

// MARK: - Suggested prompts (algorithmic, derived from calendar — no LLM)

extension ChatViewModel {

    func cancelSuggestionsGeneration() {
        isGeneratingSuggestions = false
    }

    func generateSuggestedPrompts() async {
        guard !isGeneratingSuggestions else { return }
        suggestedPrompts = Self.buildPrompts(from: calendarService)
    }

    // MARK: - Algorithm

    private static func buildPrompts(from service: CalendarServiceProtocol) -> [String] {
        guard service.isAuthorized else { return genericPrompts() }

        let cal     = Calendar.current
        let now     = Date.now
        let hour    = cal.component(.hour, from: now)
        let weekday = cal.component(.weekday, from: now) // 1=Sun … 7=Sat

        let todayStart    = cal.startOfDay(for: now)
        let todayEnd      = cal.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let tomorrowStart = todayEnd
        let tomorrowEnd   = cal.date(byAdding: .day, value: 2, to: todayStart) ?? todayStart
        let weekendStart  = nextWeekendStart(after: now, cal: cal)
        let weekEnd       = cal.date(byAdding: .day, value: 7, to: todayStart) ?? todayStart

        let remaining = service.events(in: now, end: todayEnd)
            .filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
        let tomorrow  = service.events(in: tomorrowStart, end: tomorrowEnd)
            .filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
        let thisWeek  = service.events(in: now, end: weekEnd)
            .filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
        let nextEvent = remaining.first ?? thisWeek.first

        let isEvening  = hour >= 17
        let isMorning  = hour < 12
        let isWeekend  = weekday == 1 || weekday == 7
        let isFriday   = weekday == 6
        let isThursday = weekday == 5
        let isMonday   = weekday == 2

        return [
            overviewPrompt(isEvening: isEvening, isMorning: isMorning, isMonday: isMonday,
                           remaining: remaining, tomorrow: tomorrow),
            nextEventPrompt(nextEvent: nextEvent, now: now, cal: cal, isMorning: isMorning),
            tomorrowPrompt(isEvening: isEvening, isMorning: isMorning, tomorrow: tomorrow),
            utilityPrompt(isEvening: isEvening, isMorning: isMorning, isMonday: isMonday,
                          isThursday: isThursday, isFriday: isFriday, isWeekend: isWeekend,
                          remaining: remaining, weekendStart: weekendStart, cal: cal, service: service),
        ]
    }

    // ── Q1: Overview ────────────────────────────────────────────────────────

    private static func overviewPrompt(
        isEvening: Bool, isMorning: Bool, isMonday: Bool,
        remaining: [CalendarEventInfo], tomorrow: [CalendarEventInfo]
    ) -> String {
        if isEvening {
            return tomorrow.isEmpty ? "What does tomorrow look like?" : "What's on my agenda tomorrow?"
        } else if isMonday && isMorning {
            return "What does my week look like?"
        } else if remaining.isEmpty {
            return "Do I have anything today?"
        } else if isMorning {
            return "What's my day looking like?"
        } else {
            return "What's left on my schedule today?"
        }
    }

    // ── Q2: Next specific event ──────────────────────────────────────────────

    private static func nextEventPrompt(
        nextEvent: CalendarEventInfo?, now: Date, cal: Calendar, isMorning: Bool
    ) -> String {
        guard let event = nextEvent, let title = event.title, !title.isEmpty else {
            return isMorning ? "Am I free this afternoon?" : "Am I free tomorrow?"
        }
        let short = clamp(title, to: 20)
        let minsUntil = Int(event.startDate.timeIntervalSince(now) / 60)
        if minsUntil < ChatConstants.minutesPerHour {
            return "How long until \(short)?"
        } else if cal.isDateInToday(event.startDate) {
            return "When does \(short) start?"
        } else if cal.isDateInTomorrow(event.startDate) {
            return "What time is \(short) tomorrow?"
        } else {
            return "When is \(short)?"
        }
    }

    // ── Q3: Tomorrow / add ───────────────────────────────────────────────────

    private static func tomorrowPrompt(
        isEvening: Bool, isMorning: Bool, tomorrow: [CalendarEventInfo]
    ) -> String {
        if isEvening {
            if tomorrow.count == 1, let title = tomorrow.first?.title, !title.isEmpty {
                return "What time is \(clamp(title, to: 20)) tomorrow?"
            } else if tomorrow.isEmpty {
                return "Add a meeting tomorrow morning"
            } else {
                return "What's my first meeting tomorrow?"
            }
        } else if tomorrow.isEmpty {
            return isMorning ? "Add a meeting this afternoon" : "Add a meeting tomorrow"
        } else {
            return "What's happening tomorrow?"
        }
    }

    // ── Q4: Utility / contextual ─────────────────────────────────────────────

    private static func utilityPrompt(
        isEvening: Bool, isMorning: Bool, isMonday: Bool, isThursday: Bool,
        isFriday: Bool, isWeekend: Bool, remaining: [CalendarEventInfo],
        weekendStart: Date?, cal: Calendar, service: CalendarServiceProtocol
    ) -> String {
        if (isThursday || isFriday) && !isWeekend, let wsStart = weekendStart {
            let weekendEnd = cal.date(byAdding: .day, value: 2, to: wsStart) ?? wsStart
            let weekendEvents = service.events(in: wsStart, end: weekendEnd).filter { !$0.isAllDay }
            return weekendEvents.isEmpty ? "Am I free this weekend?" : "What's on this weekend?"
        } else if isMonday && isMorning {
            return "Find a free hour today"
        } else if remaining.count >= 3 {
            return "When am I free today?"
        } else {
            return isEvening ? "Find a free hour tomorrow" : "Find a free hour today"
        }
    }

    // MARK: - Helpers

    private static func clamp(_ s: String, to max: Int) -> String {
        s.count > max ? String(s.prefix(max - 1)) + "…" : s
    }

    private static func nextWeekendStart(after date: Date, cal: Calendar) -> Date? {
        // Returns the upcoming Saturday (weekday 7) from `date`.
        var comps = DateComponents()
        comps.weekday = 7
        return cal.nextDate(after: date, matching: comps, matchingPolicy: .nextTime)
    }

    private static func genericPrompts() -> [String] {
        [
            "What's on my calendar today?",
            "Am I free this afternoon?",
            "Add a meeting tomorrow",
            "Find a free hour today",
        ]
    }
}
