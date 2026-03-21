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

        let cal      = Calendar.current
        let now      = Date.now
        let hour     = cal.component(.hour, from: now)
        let weekday  = cal.component(.weekday, from: now) // 1=Sun … 7=Sat

        let todayStart    = cal.startOfDay(for: now)
        let todayEnd      = cal.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let tomorrowStart = todayEnd
        let tomorrowEnd   = cal.date(byAdding: .day, value: 2, to: todayStart) ?? todayStart
        let weekendStart  = nextWeekendStart(after: now, cal: cal)
        let weekEnd       = cal.date(byAdding: .day, value: 7, to: todayStart) ?? todayStart

        let remaining  = service.events(in: now, end: todayEnd)
            .filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
        let tomorrow   = service.events(in: tomorrowStart, end: tomorrowEnd)
            .filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
        let thisWeek   = service.events(in: now, end: weekEnd)
            .filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
        let nextEvent  = remaining.first ?? thisWeek.first

        let isEvening  = hour >= 17
        let isMorning  = hour < 12
        let isWeekend  = weekday == 1 || weekday == 7
        let isFriday   = weekday == 6
        let isThursday = weekday == 5
        let isMonday   = weekday == 2

        var prompts: [String] = []

        // ── Q1: Overview ────────────────────────────────────────────────────
        if isEvening {
            prompts.append(tomorrow.isEmpty
                ? "What does tomorrow look like?"
                : "What's on my agenda tomorrow?")
        } else if isMonday && isMorning {
            prompts.append("What does my week look like?")
        } else if remaining.isEmpty {
            prompts.append("Do I have anything today?")
        } else if isMorning {
            prompts.append("What's my day looking like?")
        } else {
            prompts.append("What's left on my schedule today?")
        }

        // ── Q2: Next specific event ─────────────────────────────────────────
        if let event = nextEvent, let title = event.title, !title.isEmpty {
            let short  = clamp(title, to: 20)
            let minsUntil = Int(event.startDate.timeIntervalSince(now) / 60)
            if minsUntil < ChatConstants.minutesPerHour {
                prompts.append("How long until \(short)?")
            } else if cal.isDateInToday(event.startDate) {
                prompts.append("When does \(short) start?")
            } else if cal.isDateInTomorrow(event.startDate) {
                prompts.append("What time is \(short) tomorrow?")
            } else {
                prompts.append("When is \(short)?")
            }
        } else {
            prompts.append(isMorning ? "Am I free this afternoon?" : "Am I free tomorrow?")
        }

        // ── Q3: Tomorrow / add ──────────────────────────────────────────────
        if isEvening {
            if tomorrow.count == 1, let title = tomorrow.first?.title, !title.isEmpty {
                prompts.append("What time is \(clamp(title, to: 20)) tomorrow?")
            } else if tomorrow.isEmpty {
                prompts.append("Add a meeting tomorrow morning")
            } else {
                prompts.append("What's my first meeting tomorrow?")
            }
        } else if tomorrow.isEmpty {
            prompts.append(isMorning ? "Add a meeting this afternoon" : "Add a meeting tomorrow")
        } else {
            prompts.append("What's happening tomorrow?")
        }

        // ── Q4: Utility / contextual ────────────────────────────────────────
        if (isThursday || isFriday) && !isWeekend,
           let wsStart = weekendStart {
            let weekendEnd = cal.date(byAdding: .day, value: 2, to: wsStart) ?? wsStart
            let weekendEvents = service.events(in: wsStart, end: weekendEnd)
                .filter { !$0.isAllDay }
            prompts.append(weekendEvents.isEmpty
                ? "Am I free this weekend?"
                : "What's on this weekend?")
        } else if isMonday && isMorning {
            prompts.append("Find a free hour today")
        } else if remaining.count >= 3 {
            prompts.append("When am I free today?")
        } else {
            prompts.append(isEvening
                ? "Find a free hour tomorrow"
                : "Find a free hour today")
        }

        return prompts
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
