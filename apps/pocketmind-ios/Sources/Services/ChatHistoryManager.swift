import Foundation

/// Owns chat history persistence — reading from and writing to disk.
/// Extracted from ChatViewModel to keep it single-responsibility.
@MainActor
final class ChatHistoryManager {

    // Compile-time constant — safe to mark nonisolated(unsafe) as it is never mutated.
    nonisolated(unsafe) static let historyURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chat_history.json")
    }()

    /// Loads persisted messages from disk. Returns an empty array on any failure.
    func load() -> [ChatMessage] {
        guard let data = try? Data(contentsOf: Self.historyURL),
              let saved = try? JSONDecoder().decode([ChatMessage].self, from: data)
        else { return [] }
        return saved
    }

    /// Persists messages to disk on a background thread. System roles are excluded.
    func save(_ messages: [ChatMessage]) {
        let filtered = messages.filter { $0.role != .system }
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(filtered) {
                try? data.write(to: ChatHistoryManager.historyURL, options: .atomic)
            }
        }
    }

    /// Removes the persisted history file.
    func clear() {
        try? FileManager.default.removeItem(at: Self.historyURL)
    }
}
