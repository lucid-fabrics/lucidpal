---
sidebar_position: 4
---

# Session Management

How LucidPal persists and navigates multiple chat sessions.

## Data Model

Two types represent session data at different granularities:

```swift
// Lightweight — stored in index.json, loaded for the session list
struct ChatSessionMeta: Identifiable, Codable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var lastMessagePreview: String?   // first 120 chars of last non-system message
    var isPinned: Bool                // pinned sessions float to the top of the list
}

// Full session — loaded on demand when opening a chat
struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]

    var templateID: String?              // optional conversation template ID
    var meta: ChatSessionMeta { get }   // computed — no duplication
    static func new(templateID: String? = nil) -> ChatSession  // creates empty session with UUID
}
```

The split avoids loading all messages into memory just to render the session list. `loadIndex()` is called to populate the session list; `loadSession(id:)` is called lazily only when the user opens a specific chat.

## Storage Layout

```
Documents/
└── sessions/
    ├── index.json                  ← [ChatSessionMeta] array (sorted newest first)
    ├── <uuid>.json                 ← Full ChatSession per conversation
    └── <uuid>.json
```

System messages (role `.system`) are excluded from persistence — the system prompt is rebuilt on each launch from the current model and settings.

## Save Path

`save(_:)` is non-blocking — it dispatches a `Task.detached(priority: .utility)` for the JSON encode + write and returns the task handle. The in-memory index is updated synchronously so the list reflects changes immediately.

```swift
@discardableResult
func save(_ session: ChatSession) -> Task<Void, Never> {
    let task = Task.detached(priority: .utility) {
        // encode + atomic write on background thread
    }
    updateIndex(with: session.meta)   // synchronous index update
    return task
}
```

## Search

`SessionManager` exposes a full-text search over all persisted messages:

```swift
func searchMessages(query: String) -> [(meta: ChatSessionMeta, snippet: String)]
```

The search is case-insensitive and scans message content across every session. Each result includes a centred snippet (≈60 characters of context around the first match) for display in the session list. The ViewModel layer debounces the query and calls this to power the session list search bar.

## SessionListViewModel

`SessionListViewModel` is the `@MainActor ObservableObject` that drives the session list UI. It owns the in-memory `[ChatSessionMeta]` array and bridges between `SessionManager` and the SwiftUI views.

### Responsibilities

| Responsibility | Method(s) |
|---|---|
| Session CRUD | `createSession(templateID:)`, `deleteSession(id:)`, `renameSession(id:title:)`, `refreshSessions()` |
| Pinning | `togglePin(id:)` |
| Session grouping & search | `groupedSessions(searchText:)`, `filteredSessions(searchText:)` |
| Siri routing | `scheduleSiriQuery(_:)`, `siriNavigationMeta` published property |
| Siri "Add Event" routing | `scheduleCreateEvent(_:)`, `pendingEventCreation` published property |
| Calendar event creation | `createCalendarEvent(title:start:end:isAllDay:location:notes:)` |
| ChatViewModel factory | `makeChatViewModel(for:initialQuery:startWithVoice:)` |
| Calendar hero panel data | `nextUpcomingEvent()`, `todayEventCount()` |

### groupedSessions(searchText:)

Returns `[SessionGroup]` for display in the session list. Groups are built from `filteredSessions(searchText:)` and ordered:

1. **Pinned** — sessions with `isPinned == true` (omitted when empty)
2. **Today** — `updatedAt` is today
3. **Yesterday** — `updatedAt` is yesterday
4. **This Week** — `updatedAt` within the last 7 days (exclusive of today and yesterday)
5. **Earlier** — everything older

Empty groups are omitted. Within each group, sessions retain their sort order from `filteredSessions`.

When `searchText` is non-empty, `filteredSessions` runs a two-phase search:
1. Title match — `localizedCaseInsensitiveContains`
2. Content match — calls `SessionManager.searchMessages(query:)` for sessions not already matched by title; the matching message snippet replaces `lastMessagePreview` for display

### pendingQueryBySessionID

```swift
var pendingQueryBySessionID: [UUID: String] = [:]
```

Set by `scheduleSiriQuery(_:)` when a Siri intent arrives. `SessionListView` creates a new session, stores the query here keyed by the new session's UUID, then navigates to it. `ChatSessionContainer` consumes the entry on init and auto-sends the query as the first message.

### createCalendarEvent()

Delegates to `CalendarServiceProtocol.createEvent(...)` with the parameters supplied by `CreateEventSheet`. This is the write path for Siri "Add Event" intents — `scheduleCreateEvent(_:)` populates `pendingEventCreation` which triggers `CreateEventSheet`; the sheet calls `createCalendarEvent()` on confirmation.

## NoOpChatHistoryManager

When `ChatViewModel` operates in session mode (i.e., a `SessionManager` is active), the old single-file `ChatHistoryManager` is replaced by `NoOpChatHistoryManager`:

```swift
/// No-op history manager — used when ChatViewModel operates in session mode.
/// Persistence is handled by SessionManager instead.
final class NoOpChatHistoryManager: ChatHistoryManagerProtocol {
    func load() -> [ChatMessage] { [] }
    func save(_ messages: [ChatMessage]) -> Task<Void, Never> { Task {} }
    func clear() {}
}
```

This ensures the legacy `chat_history.json` single-file format is never written when sessions are enabled. The `ChatHistoryManagerProtocol` abstraction lets `ChatViewModel` remain unaware of which backing store is active.

## Legacy Migration

On first launch after upgrade from the single-session version, `SessionManager` automatically migrates `chat_history.json`:

```
Documents/chat_history.json (legacy)
        ↓
migrate() called in init
        ↓
Creates a new ChatSession from the message array
        ↓
Saves to sessions/<uuid>.json + updates index
        ↓
Removes chat_history.json
```

Migration is a no-op if the legacy file doesn't exist.
