import Foundation

protocol ChatHistoryManagerProtocol {
    func load() -> [ChatMessage]
    func save(_ messages: [ChatMessage])
    func clear()
}

/// Owns chat history persistence — reading from and writing to disk.
/// Extracted from ChatViewModel to keep it single-responsibility.
@MainActor
final class ChatHistoryManager: ChatHistoryManagerProtocol {

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
            guard let data = try? JSONEncoder().encode(filtered) else { return }
            do {
                try data.write(to: ChatHistoryManager.historyURL, options: .atomic)
            } catch {
                print("[ChatHistoryManager] Failed to write history: \(error)")
            }
        }
    }

    /// Removes the persisted history file.
    func clear() {
        do {
            try FileManager.default.removeItem(at: Self.historyURL)
        } catch {
            print("[ChatHistoryManager] Failed to clear history: \(error)")
        }
    }
}
