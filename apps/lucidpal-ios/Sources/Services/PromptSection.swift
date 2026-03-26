import Foundation

// MARK: - Protocol

/// A single, self-contained block of text contributed to the LLM system prompt.
///
/// Add a new capability (e.g. Contacts, Reminders with dedicated instructions) by creating
/// a new conforming type — the assembler (`SystemPromptBuilder`) requires no modification (OCP).
@MainActor
protocol PromptSection {
    /// Returns the prompt text for this section, or nil if the section is inactive/disabled.
    func build() async -> String?
    /// False for sections that must be excluded from the synthesis re-generation pass.
    var includedInSynthesis: Bool { get }
}

extension PromptSection {
    var includedInSynthesis: Bool { true }
}

// MARK: - IdentityPromptSection

/// "You are LucidPal…" — identity, date, timezone, locale, city.
struct IdentityPromptSection: PromptSection {
    let settings: any AppSettingsProtocol
    let calendarService: any CalendarServiceProtocol

    func build() async -> String? {
        let calendarEnabled = settings.calendarAccessEnabled && calendarService.isAuthorized
        let contextEnabled = settings.notesAccessEnabled
            || settings.remindersAccessEnabled
            || settings.mailAccessEnabled
        let today = formattedToday()
        let timezone = TimeZone.current.identifier
        let locale = Locale.current.region?.identifier ?? ""
        let cityContext: String = {
            let city = settings.userCity
            guard settings.locationEnabled, !city.isEmpty else { return "" }
            return " User's city: \(city)."
        }()
        return """
            You are LucidPal, an on-device AI assistant\
            \(calendarEnabled ? " with direct read and write access to the user's iOS calendar" : "")\
            \(contextEnabled ? " with access to the user's Notes, Reminders, and Mail" : "").
            Today is \(today). Timezone: \(timezone).\
            \(locale.isEmpty ? "" : " Region: \(locale).")\(cityContext)
            Be concise. Use markdown for emphasis (**bold**), bullet lists (- item), and inline code (`code`). Keep responses short.
            """
    }

    private func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: .now)
    }
}

// MARK: - WebSearchPromptSection

/// WEB SEARCH TOOL instructions. Excluded from the synthesis re-generation pass.
struct WebSearchPromptSection: PromptSection {
    let settings: any WebSearchSettingsProtocol
    var includedInSynthesis: Bool { false }

    // swiftlint:disable line_length
    func build() async -> String? {
        guard settings.webSearchEnabled, credentialsPresent else { return nil }
        return """
            WEB SEARCH TOOL
            When the user asks about live/real-time data that changes daily or weekly (weather, news, sports scores, stock prices, flight status, current events), output a [WEB_SEARCH:{...}] block. The app will execute the search and re-send you the results to synthesize.

            Format: [WEB_SEARCH:{"query":"your search terms","maxResults":5}]

            Rules:
            - Use web search ONLY for genuinely time-sensitive information: today's weather, breaking news, live scores, current prices, recent releases (last 1-2 months). Do NOT use for historical facts, science, math, general knowledge, definitions, how-to questions, or anything stable that your training covers.
            - Keep the query concise and specific.
            - Output ONLY the [WEB_SEARCH:...] block — no other text in that response.
            - After receiving [SEARCH_RESULTS ...], synthesize a clear answer from those results.
            - NOT a web search: "Who is Einstein?", "What's 2+2?", "How does TCP/IP work?", "What is photosynthesis?" — answer these directly.
            """
    }
    // swiftlint:enable line_length

    private var credentialsPresent: Bool {
        switch settings.webSearchProvider {
        case .brave:   return !settings.braveApiKey.isEmpty
        case .searxng: return !settings.webSearchEndpoint.isEmpty
        }
    }
}

// MARK: - CrossAppContextSection

/// Notes / Reminders / Mail cross-app context fetched from the ContextService.
struct CrossAppContextSection: PromptSection {
    let contextService: any ContextServiceProtocol
    let settings: any AppSettingsProtocol

    func build() async -> String? {
        guard settings.notesAccessEnabled
            || settings.remindersAccessEnabled
            || settings.mailAccessEnabled else { return nil }
        return await contextService.fetchContext(query: nil)
    }
}
