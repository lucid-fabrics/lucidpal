import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isGenerating = false
    @Published var errorMessage: String?

    private let llmService: LLMService
    private let calendarService: CalendarService
    private let settings: AppSettings

    init(llmService: LLMService, calendarService: CalendarService, settings: AppSettings) {
        self.llmService = llmService
        self.calendarService = calendarService
        self.settings = settings
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }

        inputText = ""
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)

        let assistantMsg = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMsg)
        let assistantIndex = messages.count - 1

        isGenerating = true
        errorMessage = nil

        let systemPrompt = buildSystemPrompt()
        let prompt = LLMService.buildPrompt(messages: messages.dropLast(), systemPrompt: systemPrompt)

        do {
            for try await token in llmService.generate(prompt: prompt) {
                messages[assistantIndex].content += token
            }
        } catch {
            messages[assistantIndex].content = "Error: \(error.localizedDescription)"
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    func clearHistory() {
        messages = []
    }

    private func buildSystemPrompt() -> String {
        var parts: [String] = [
            "You are PocketMind, a helpful AI calendar assistant running entirely on-device.",
            "Today is \(formattedToday()).",
            "Be concise. Use plain text, no markdown."
        ]

        if settings.calendarAccessEnabled {
            let events = calendarService.fetchEvents(from: .now, days: 7)
            if !events.isEmpty {
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
