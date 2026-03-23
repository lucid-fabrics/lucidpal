import Foundation
import OSLog

private let systemPromptLogger = Logger(subsystem: "app.pocketmind", category: "Chat")

// MARK: - Protocols

/// Builds the LLM system prompt and synthesis prompt from the registered PromptSections.
@MainActor
protocol PromptAssemblerProtocol {
    func buildSystemPrompt() async -> String
    /// System prompt for the web-search synthesis pass — identical to buildSystemPrompt but
    /// WITHOUT sections that are excluded from synthesis (e.g. web search tool instructions),
    /// so the model cannot recurse into another search.
    func buildSynthesisPrompt() async -> String
}

/// Parses and executes `[CALENDAR_ACTION:{...}]` blocks embedded in LLM response text.
@MainActor
protocol CalendarActionExecutorProtocol {
    func executeCalendarActions(in text: String) async -> (content: String, previews: [CalendarEventPreview], freeSlots: [CalendarFreeSlot])
}

/// Extracts a `[WEB_SEARCH:{...}]` payload from LLM response text.
@MainActor
protocol WebSearchExtractorProtocol {
    func extractWebSearchQuery(from text: String) -> (query: String, maxResults: Int)?
}

/// Combined typealias — ChatViewModel and tests depend on this single type; no call-site changes needed.
/// Each constituent protocol has a single responsibility (ISP).
typealias SystemPromptBuilderProtocol = PromptAssemblerProtocol
    & CalendarActionExecutorProtocol
    & WebSearchExtractorProtocol

// MARK: - Implementation

/// Assembles the LLM system prompt from an ordered list of `PromptSection` values,
/// and executes calendar action / web search blocks found in LLM responses.
///
/// Adding a new tool capability = create a new `PromptSection` conformer and inject it here.
/// This class does not need to change (OCP).
@MainActor
final class SystemPromptBuilder: SystemPromptBuilderProtocol {

    private let sections: [any PromptSection]
    private let calendarActionController: any CalendarActionControllerProtocol

    // Matches [CALENDAR_ACTION:{...}] — negative lookahead \}(?!\]) allows `}` inside JSON string values.
    static let actionPattern = #"\[CALENDAR_ACTION:(\{(?:[^}]|\}(?!\]))*\})\]"#

    private static let calendarActionRegex: NSRegularExpression = {
        // safe: literal regex pattern — preconditionFailure guards nil; failure is a programming error
        guard let regex = try? NSRegularExpression(
            pattern: actionPattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            preconditionFailure("Invalid calendarActionRegex pattern: \(actionPattern)")
        }
        return regex
    }()

    // Matches [WEB_SEARCH:{...}] — same lookahead pattern as calendarActionRegex.
    static let webSearchPattern = #"\[WEB_SEARCH:(\{(?:[^}]|\}(?!\]))*\})\]"#

    private static let webSearchRegex: NSRegularExpression = {
        guard let regex = try? NSRegularExpression(
            pattern: webSearchPattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            preconditionFailure("Invalid webSearchRegex pattern: \(webSearchPattern)")
        }
        return regex
    }()

    // MARK: - Init

    init(sections: [any PromptSection], calendarActionController: any CalendarActionControllerProtocol) {
        self.sections = sections
        self.calendarActionController = calendarActionController
    }

    /// Convenience initialiser for production use — creates the standard section set.
    convenience init(
        calendarService: any CalendarServiceProtocol,
        contextService: any ContextServiceProtocol,
        settings: any AppSettingsProtocol,
        calendarActionController: any CalendarActionControllerProtocol
    ) {
        self.init(
            sections: [
                IdentityPromptSection(settings: settings, calendarService: calendarService),
                CalendarPromptSection(calendarService: calendarService, settings: settings),
                WebSearchPromptSection(settings: settings),
                CrossAppContextSection(contextService: contextService, settings: settings),
            ],
            calendarActionController: calendarActionController
        )
    }

    // MARK: - PromptAssemblerProtocol

    func buildSystemPrompt() async -> String {
        let prompt = await assemblePrompt(synthesisOnly: false)
        systemPromptLogger.info("🧠 SYSTEM_PROMPT: \(prompt, privacy: .public)")
        DebugLogStore.shared.log("SYSTEM_PROMPT: \(prompt)", category: "Chat")
        return prompt
    }

    func buildSynthesisPrompt() async -> String {
        let prompt = await assemblePrompt(synthesisOnly: true)
        systemPromptLogger.info("🧠 SYNTHESIS_PROMPT: \(prompt, privacy: .public)")
        DebugLogStore.shared.log("SYNTHESIS_PROMPT: \(prompt)", category: "Chat")
        return prompt
    }

    // MARK: - CalendarActionExecutorProtocol

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

    // MARK: - WebSearchExtractorProtocol

    func extractWebSearchQuery(from text: String) -> (query: String, maxResults: Int)? {
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = Self.webSearchRegex.firstMatch(in: text, range: range),
              let jsonRange = Range(match.range(at: 1), in: text),
              let data = String(text[jsonRange]).data(using: .utf8) else { return nil }
        do {
            let payload = try JSONDecoder().decode(WebSearchPayload.self, from: data)
            return (query: payload.query, maxResults: payload.maxResults ?? 5)
        } catch {
            systemPromptLogger.error("WebSearch: failed to decode payload: \(error)")
            return nil
        }
    }

    // MARK: - Private

    private func assemblePrompt(synthesisOnly: Bool) async -> String {
        var parts: [String] = []
        for section in sections {
            if synthesisOnly, !section.includedInSynthesis { continue }
            if let text = await section.build() { parts.append(text) }
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Web search payload

private struct WebSearchPayload: Decodable {
    let query: String
    let maxResults: Int?
}
