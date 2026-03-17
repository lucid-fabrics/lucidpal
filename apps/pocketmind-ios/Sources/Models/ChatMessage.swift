import Foundation

struct CalendarEventPreview: Codable, Equatable, Sendable {
    let title: String
    let start: Date
    let end: Date
    let calendarName: String?
}

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let role: MessageRole
    var content: String
    var thinkingContent: String?
    var isThinking: Bool
    var calendarEventPreviews: [CalendarEventPreview]
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, thinkingContent: String? = nil, isThinking: Bool = false, calendarEventPreviews: [CalendarEventPreview] = [], timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.thinkingContent = thinkingContent
        self.isThinking = isThinking
        self.calendarEventPreviews = calendarEventPreviews
        self.timestamp = timestamp
    }

    var isUser: Bool { role == .user }
}
