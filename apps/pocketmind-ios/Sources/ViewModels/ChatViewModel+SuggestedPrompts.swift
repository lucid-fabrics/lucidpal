import Foundation
import OSLog

private let suggestionsLogger = Logger(subsystem: "com.pocketmind", category: "SuggestedPrompts")

// MARK: - Suggested prompts generation + caching
// Separated from the core ViewModel to keep each file under 400 lines.

extension ChatViewModel {

    static let fallbackPrompts = [
        "What's on my calendar this week?",
        "Add a meeting tomorrow at 2pm",
        "Find a free 1-hour slot today",
        "Delete my next dentist appointment",
    ]

    func cancelSuggestionsGeneration() {
        suggestionsTask?.cancel()
        suggestionsTask = nil
        isGeneratingSuggestions = false
    }

    func generateSuggestedPrompts() async {
        guard !isGeneratingSuggestions else { return }
        if let cached = loadCachedSuggestions() {
            suggestedPrompts = cached
            return
        }
        isGeneratingSuggestions = true
        suggestionsTask = Task { [weak self] in
            guard let self else { return }
            defer { isGeneratingSuggestions = false }
            let system = "Return ONLY a valid JSON array of exactly 4 short questions a user might ask a calendar assistant. Each under 8 words. No markdown, no extra text. Format: [\"Q1?\",\"Q2?\",\"Q3?\",\"Q4?\"]"
            let userMsg = ChatMessage(role: .user, content: "Give me 4 suggested prompts.")
            var output = ""
            do {
                for try await token in llmService.generate(systemPrompt: system, messages: [userMsg], thinkingEnabled: false) {
                    guard !Task.isCancelled else { return }
                    output += token
                }
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            if let parsed = Self.parsePromptArray(from: output) {
                suggestedPrompts = parsed
                cacheSuggestions(parsed)
            }
        }
        await suggestionsTask?.value
    }

    private static func parsePromptArray(from output: String) -> [String]? {
        guard let start = output.firstIndex(of: "["),
              let end = output.lastIndex(of: "]"),
              start <= end else { return nil }
        let jsonString = String(output[start...end])
        guard let data = jsonString.data(using: .utf8) else { return nil }
        let array: [String]
        do {
            array = try JSONDecoder().decode([String].self, from: data)
        } catch {
            suggestionsLogger.error("Failed to decode suggestions JSON: \(error)")
            return nil
        }
        guard array.count >= 2 else { return nil }
        return Array(array.prefix(4))
    }

    private func loadCachedSuggestions() -> [String]? {
        let defaults = UserDefaults.standard
        guard let date = defaults.object(forKey: UserDefaultsKeys.suggestionsCacheDate) as? Date,
              Calendar.current.isDateInToday(date),
              let data = defaults.data(forKey: UserDefaultsKeys.suggestionsCache) else { return nil }
        do {
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            suggestionsLogger.error("Failed to decode cached suggestions: \(error)")
            return nil
        }
    }

    private func cacheSuggestions(_ prompts: [String]) {
        do {
            let data = try JSONEncoder().encode(prompts)
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.suggestionsCache)
            UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.suggestionsCacheDate)
        } catch {
            suggestionsLogger.error("Failed to encode suggestions for cache: \(error)")
        }
    }
}
