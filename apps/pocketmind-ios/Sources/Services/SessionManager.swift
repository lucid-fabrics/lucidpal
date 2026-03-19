import Foundation

@MainActor
protocol SessionManagerProtocol {
    func loadIndex() -> [ChatSessionMeta]
    func loadSession(id: UUID) -> ChatSession?
    @discardableResult func save(_ session: ChatSession) -> Task<Void, Never>
    func delete(id: UUID)
    @discardableResult func renameSession(id: UUID, title: String) -> Task<Void, Never>
}

/// Manages multiple chat sessions on disk.
/// Each session is stored as `Documents/sessions/<uuid>.json`.
/// A lightweight index at `Documents/sessions/index.json` stores metadata without messages.
@MainActor
final class SessionManager: SessionManagerProtocol {

    // nonisolated(unsafe): stored once in init and never mutated after — safe to read from any context.
    nonisolated(unsafe) private let sessionsDirectory: URL
    nonisolated(unsafe) private let indexURL: URL

    /// Creates a `SessionManager` rooted at `directory`.
    /// Pass a custom temp path in tests to avoid polluting the real Documents directory.
    init(directory: URL? = nil) {
        let root = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        sessionsDirectory = root.appendingPathComponent("sessions", isDirectory: true)
        indexURL = sessionsDirectory.appendingPathComponent("index.json")
        do {
            try FileManager.default.createDirectory(
                at: sessionsDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            print("[SessionManager] Failed to create sessions directory: \(error)")
        }
        migrate()
    }

    // MARK: - Protocol

    func loadIndex() -> [ChatSessionMeta] {
        let data: Data
        do {
            data = try Data(contentsOf: indexURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []  // expected on first launch — index has not been written yet
        } catch {
            print("[SessionManager] Failed to read index file: \(error)")
            return []
        }
        do {
            return try JSONDecoder().decode([ChatSessionMeta].self, from: data)
        } catch {
            print("[SessionManager] Failed to decode index: \(error)")
            return []
        }
    }

    func loadSession(id: UUID) -> ChatSession? {
        let url = sessionURL(for: id)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil  // session file absent — normal if session was deleted externally
        } catch {
            print("[SessionManager] Failed to read session \(id): \(error)")
            return nil
        }
        do {
            return try JSONDecoder().decode(ChatSession.self, from: data)
        } catch {
            print("[SessionManager] Failed to decode session \(id): \(error)")
            return nil
        }
    }

    @discardableResult
    func save(_ session: ChatSession) -> Task<Void, Never> {
        let url = sessionURL(for: session.id)
        // Exclude system messages from persistence
        let filtered = ChatSession(
            id: session.id,
            title: session.title,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt,
            messages: session.messages.filter { $0.role != .system }
        )
        let task = Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(filtered)
                try data.write(to: url, options: .atomic)
            } catch {
                print("[SessionManager] Failed to save session \(filtered.id): \(error)")
            }
        }
        updateIndex(with: session.meta)
        return task
    }

    func delete(id: UUID) {
        do {
            try FileManager.default.removeItem(at: sessionURL(for: id))
        } catch {
            print("[SessionManager] Failed to delete session \(id): \(error)")
        }
        var index = loadIndex()
        index.removeAll { $0.id == id }
        saveIndex(index)
    }

    @discardableResult
    func renameSession(id: UUID, title: String) -> Task<Void, Never> {
        guard var session = loadSession(id: id) else { return Task {} }
        session.title = title
        return save(session)
    }

    // MARK: - Private

    private func sessionURL(for id: UUID) -> URL {
        sessionsDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func updateIndex(with meta: ChatSessionMeta) {
        var index = loadIndex()
        if let i = index.firstIndex(where: { $0.id == meta.id }) {
            index[i] = meta
        } else {
            index.insert(meta, at: 0)
        }
        saveIndex(index)
    }

    private func saveIndex(_ index: [ChatSessionMeta]) {
        do {
            let data = try JSONEncoder().encode(index)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            print("[SessionManager] Failed to save index: \(error)")
        }
    }

    // MARK: - Migration

    /// Migrates legacy single-file `chat_history.json` to the multi-session format.
    private func migrate() {
        let legacyURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chat_history.json")
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }
        let data: Data
        let messages: [ChatMessage]
        do {
            data = try Data(contentsOf: legacyURL)
            messages = try JSONDecoder().decode([ChatMessage].self, from: data)
        } catch {
            print("[SessionManager] Failed to read legacy history: \(error)")
            try? FileManager.default.removeItem(at: legacyURL)
            return
        }
        guard !messages.isEmpty else {
            try? FileManager.default.removeItem(at: legacyURL)
            return
        }
        let firstUserContent = messages.first(where: { $0.role == .user })?.content ?? "Chat"
        let session = ChatSession(
            id: UUID(),
            title: String(firstUserContent.prefix(ChatConstants.maxSessionTitleLength)),
            createdAt: messages.first?.timestamp ?? .now,
            updatedAt: messages.last?.timestamp ?? .now,
            messages: messages
        )
        save(session)
        do {
            try FileManager.default.removeItem(at: legacyURL)
        } catch {
            print("[SessionManager] Failed to remove legacy chat_history.json: \(error)")
        }
    }
}
