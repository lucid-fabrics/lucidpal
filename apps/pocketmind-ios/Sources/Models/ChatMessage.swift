import Foundation

/// Snapshot of proposed changes before a user-confirmed update.
struct PendingCalendarUpdate: Codable, Equatable, Sendable {
    var title: String?
    var start: Date?
    var end: Date?
    var location: String?
    var notes: String?
    var reminderMinutes: Int?
    var isAllDay: Bool?
}

struct CalendarEventPreview: Codable, Equatable, Sendable {
    enum PreviewState: String, Codable, Sendable {
        case created
        case updated
        case rescheduled
        case pendingDeletion
        case deleted
        case deletionCancelled
        case restored
        case pendingUpdate
        case updateCancelled
    }

    let id: UUID
    var title: String
    var start: Date
    var end: Date
    let calendarName: String?
    var state: PreviewState
    /// EKEvent.eventIdentifier — stored so confirmed deletion can locate the event.
    var eventIdentifier: String?
    /// Minutes before event for reminder alarm (nil = no alarm).
    var reminderMinutes: Int?
    var isAllDay: Bool
    var recurrence: String?
    /// Proposed changes for pendingUpdate state.
    var pendingUpdate: PendingCalendarUpdate?

    init(
        id: UUID = UUID(),
        title: String,
        start: Date,
        end: Date,
        calendarName: String?,
        state: PreviewState = .created,
        eventIdentifier: String? = nil,
        reminderMinutes: Int? = nil,
        isAllDay: Bool = false,
        recurrence: String? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.calendarName = calendarName
        self.state = state
        self.eventIdentifier = eventIdentifier
        self.reminderMinutes = reminderMinutes
        self.isAllDay = isAllDay
        self.recurrence = recurrence
        self.pendingUpdate = nil
    }
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
