import Foundation

/// Lightweight session metadata stored in the index — no messages to keep index reads fast.
struct ChatSessionMeta: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var lastMessagePreview: String?

    init(id: UUID, title: String, createdAt: Date, updatedAt: Date, lastMessagePreview: String? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMessagePreview = lastMessagePreview
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Full session including messages — loaded on demand when opening a chat.
struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]

    var meta: ChatSessionMeta {
        let lastContent = messages.last(where: { $0.role != .system })?.content
        let preview = lastContent.map { String($0.prefix(120)) }
        return ChatSessionMeta(id: id, title: title, createdAt: createdAt, updatedAt: updatedAt, lastMessagePreview: preview)
    }

    static func new() -> ChatSession {
        let now = Date.now
        return ChatSession(id: UUID(), title: "New Chat", createdAt: now, updatedAt: now, messages: [])
    }
}
