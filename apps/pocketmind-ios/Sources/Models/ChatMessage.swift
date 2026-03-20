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

/// Snapshot of a conflicting event stored alongside a preview card.
/// Codable so conflict info survives session persistence.
struct ConflictingEventSnapshot: Codable, Equatable, Sendable {
    let title: String
    let start: Date
    let end: Date
    let calendarName: String?
    let isRecurring: Bool
    let isAllDay: Bool
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
    /// Snapshots of events that conflict with this one (populated on create/reschedule).
    var conflictingEvents: [ConflictingEventSnapshot]
    /// True when the event no longer exists in the user's calendar (deleted externally).
    var isStale: Bool
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
        hasConflict: Bool? = nil,
        conflictingEvents: [ConflictingEventSnapshot] = [],
        isStale: Bool = false
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
        self.conflictingEvents = conflictingEvents
        self.isStale = isStale
        self.pendingUpdate = nil
    }

    // MARK: - Codable (backward compat: isStale defaults to false when key absent)

    private enum CodingKeys: String, CodingKey {
        case id, title, start, end, calendarName, state, eventIdentifier
        case reminderMinutes, isAllDay, recurrence, location, hasConflict, conflictingEvents, isStale, pendingUpdate
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        start = try c.decode(Date.self, forKey: .start)
        end = try c.decode(Date.self, forKey: .end)
        calendarName = try c.decodeIfPresent(String.self, forKey: .calendarName)
        state = try c.decode(PreviewState.self, forKey: .state)
        eventIdentifier = try c.decodeIfPresent(String.self, forKey: .eventIdentifier)
        reminderMinutes = try c.decodeIfPresent(Int.self, forKey: .reminderMinutes)
        isAllDay = try c.decode(Bool.self, forKey: .isAllDay)
        recurrence = try c.decodeIfPresent(String.self, forKey: .recurrence)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        hasConflict = try c.decodeIfPresent(Bool.self, forKey: .hasConflict)
        conflictingEvents = try c.decodeIfPresent([ConflictingEventSnapshot].self, forKey: .conflictingEvents) ?? []
        isStale = try c.decodeIfPresent(Bool.self, forKey: .isStale) ?? false
        pendingUpdate = try c.decodeIfPresent(PendingCalendarUpdate.self, forKey: .pendingUpdate)
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
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { // safe: pattern is a compile-time constant; failure is caught by preconditionFailure below
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
