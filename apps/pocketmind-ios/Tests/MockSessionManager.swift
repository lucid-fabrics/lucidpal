import Foundation
@testable import PocketMind

@MainActor
final class MockSessionManager: SessionManagerProtocol {
    private(set) var savedSessions: [ChatSession] = []
    private(set) var deletedIDs: [UUID] = []
    private var store: [UUID: ChatSession] = [:]

    func loadIndex() -> [ChatSessionMeta] {
        store.values.map { $0.meta }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadSession(id: UUID) -> ChatSession? {
        store[id]
    }

    @discardableResult
    func save(_ session: ChatSession) -> Task<Void, Never> {
        savedSessions.append(session)
        store[session.id] = session
        return Task {}
    }

    func delete(id: UUID) {
        deletedIDs.append(id)
        store.removeValue(forKey: id)
    }

    @discardableResult
    func renameSession(id: UUID, title: String) -> Task<Void, Never> {
        guard var session = store[id] else { return Task {} }
        session.title = title
        store[id] = session
        return Task {}
    }
}
