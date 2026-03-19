import Foundation

@MainActor
protocol ChatHistoryManagerProtocol {
    func load() -> [ChatMessage]
    @discardableResult func save(_ messages: [ChatMessage]) -> Task<Void, Never>
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
        let data: Data
        do {
            data = try Data(contentsOf: Self.historyURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []  // expected on first launch — no history yet
        } catch {
            print("[ChatHistoryManager] Failed to read history file: \(error)")
            return []
        }
        do {
            return try JSONDecoder().decode([ChatMessage].self, from: data)
        } catch {
            print("[ChatHistoryManager] Failed to decode history: \(error)")
            return []
        }
    }

    /// Persists messages to disk on a background thread. System roles are excluded.
    /// Returns the underlying Task — callers can await it in tests to avoid sleep-based timing.
    @discardableResult
    func save(_ messages: [ChatMessage]) -> Task<Void, Never> {
        let filtered = messages.filter { $0.role != .system }
        return Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(filtered)
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

/// No-op history manager — used when ChatViewModel operates in session mode.
/// Persistence is handled by SessionManager instead.
@MainActor
final class NoOpChatHistoryManager: ChatHistoryManagerProtocol {
    func load() -> [ChatMessage] { [] }
    @discardableResult func save(_ messages: [ChatMessage]) -> Task<Void, Never> { Task {} }
    func clear() {}
}
