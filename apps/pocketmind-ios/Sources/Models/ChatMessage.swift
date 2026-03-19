import Foundation

/// A free time slot returned by a calendar query action.
struct CalendarFreeSlot: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let start: Date
    let end: Date

    init(start: Date, end: Date) {
        self.id = UUID()
        self.start = start
        self.end = end
    }
}

/// Snapshot of proposed changes before a user-confirmed update.
struct PendingCalendarUpdate: Codable, Equatable, Sendable {
    var title: String?
    var start: Date?
    var end: Date?
    var location: String?
    var notes: String?
    var reminderMinutes: Int?
    var isAllDay: Bool?
    var recurrence: String?
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
        /// Read-only result from a list action — rendered as a grouped calendar card.
        case listed
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
    var location: String?
    /// True when the created event overlaps with an existing event.
    var hasConflict: Bool?
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
        recurrence: String? = nil,
        location: String? = nil,
        hasConflict: Bool? = nil
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
        self.location = location
        self.hasConflict = hasConflict
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

    var calendarFreeSlots: [CalendarFreeSlot]

    init(id: UUID = UUID(), role: MessageRole, content: String, thinkingContent: String? = nil, isThinking: Bool = false, calendarEventPreviews: [CalendarEventPreview] = [], calendarFreeSlots: [CalendarFreeSlot] = [], timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.thinkingContent = thinkingContent
        self.isThinking = isThinking
        self.calendarEventPreviews = calendarEventPreviews
        self.calendarFreeSlots = calendarFreeSlots
        self.timestamp = timestamp
    }

    var isUser: Bool { role == .user }

    /// True while the LLM is still streaming a [CALENDAR_ACTION:...] block
    /// and previews have not yet been populated. Used by the bubble View
    /// to show the animated "Updating calendar…" pill.
    var isStreamingAction: Bool {
        calendarEventPreviews.isEmpty && content.contains("[CALENDAR_ACTION:")
    }

    // Compiled once — NSRegularExpression is thread-safe for matching.
    private static let actionBlockRegex: NSRegularExpression = {
        let pattern = #"\[CALENDAR_ACTION:\{(?:[^}]|\}(?!\]))*\}\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else {
            preconditionFailure("Invalid actionBlockRegex pattern")
        }
        return regex
    }()

    /// Content with [CALENDAR_ACTION:...] blocks stripped for display.
    /// Removes complete blocks via regex and partial blocks still mid-stream.
    var displayContent: String {
        var text = content
        let ns = NSRange(text.startIndex..., in: text)
        text = Self.actionBlockRegex.stringByReplacingMatches(in: text, range: ns, withTemplate: "")
        // Remove any partial block still streaming (no closing ])
        if let start = text.range(of: "[CALENDAR_ACTION:") {
            text = String(text[..<start.lowerBound])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
