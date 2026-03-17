import Combine
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published private(set) var isGenerating = false
    @Published private(set) var isModelLoaded = false
    @Published var errorMessage: String?

    private let llmService: LLMService
    private let calendarService: CalendarService
    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    init(llmService: LLMService, calendarService: CalendarService, settings: AppSettings) {
        self.llmService = llmService
        self.calendarService = calendarService
        self.settings = settings
        self.isModelLoaded = llmService.isLoaded

        // Mirror LLMService state so views never observe the service directly
        llmService.$isLoaded
            .receive(on: RunLoop.main)
            .assign(to: \.isModelLoaded, on: self)
            .store(in: &cancellables)

        llmService.$isGenerating
            .receive(on: RunLoop.main)
            .assign(to: \.isGenerating, on: self)
            .store(in: &cancellables)
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating, isModelLoaded else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))

        let assistantMsg = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMsg)
        let assistantID = assistantMsg.id  // Capture ID — safe against clearHistory() mid-stream

        errorMessage = nil

        let systemPrompt = await buildSystemPrompt()
        // Snapshot history before the empty assistant placeholder
        let historySnapshot = messages.dropLast()
        let prompt = LLMService.buildPrompt(messages: Array(historySnapshot), systemPrompt: systemPrompt)

        do {
            for try await token in llmService.generate(prompt: prompt) {
                // Look up by ID each iteration — nil-safe if clearHistory() was called
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
