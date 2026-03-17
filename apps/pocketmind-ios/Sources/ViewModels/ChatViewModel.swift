import Combine
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published private(set) var isGenerating = false
    @Published private(set) var isPreparing = false
    @Published private(set) var isModelLoaded = false
    @Published var errorMessage: String?

    private let llmService: LLMService
    private let calendarService: CalendarService
    private let settings: AppSettings

    init(llmService: LLMService, calendarService: CalendarService, settings: AppSettings) {
        self.llmService = llmService
        self.calendarService = calendarService
        self.settings = settings
        self.isModelLoaded = llmService.isLoaded

        // assign(to: &$property) uses weak self internally — no retain cycle.
        llmService.$isLoaded.assign(to: &$isModelLoaded)
        llmService.$isGenerating.assign(to: &$isGenerating)
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating, isModelLoaded else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))
        errorMessage = nil

        // Build system prompt before showing the assistant placeholder —
        // prevents a visible empty bubble during the calendar fetch.
        isPreparing = true
        let systemPrompt = await buildSystemPrompt()
        isPreparing = false

        let assistantMsg = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMsg)
        let assistantID = assistantMsg.id  // Capture ID — safe against clearHistory() mid-stream

        // Snapshot history without the empty assistant placeholder
        let prompt = LLMService.buildPrompt(
            messages: Array(messages.dropLast()),
            systemPrompt: systemPrompt
        )

        do {
            for try await token in llmService.generate(prompt: prompt) {
                // ID-based lookup — nil-safe if clearHistory() wipes messages during streaming
                guard let idx = messages.firstIndex(where: { $0.id == assistantID }) else { break }
                messages[idx].content += token
            }
        } catch is CancellationError {
            // User cancelled — leave partial content visible
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx].content = "Error: \(error.localizedDescription)"
            }
            errorMessage = error.localizedDescription
        }
    }

    func cancelGeneration() {
        llmService.cancelGeneration()
    }

    func clearHistory() {
        llmService.cancelGeneration()
        messages = []
    }

    private func buildSystemPrompt() async -> String {
        var parts: [String] = [
            "You are PocketMind, a helpful AI calendar assistant running entirely on-device.",
            "Today is \(formattedToday()).",
            "Be concise. Use plain text, no markdown."
        ]

        if settings.calendarAccessEnabled {
            let events = await calendarService.fetchEvents(from: .now, days: 7)
            // Sync revocation: if OS denied access between the setting toggle and now, disable the toggle.
            if !calendarService.isAuthorized {
                settings.calendarAccessEnabled = false
            } else if !events.isEmpty {
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
