---
sidebar_position: 4
---

# Session Management

How PocketMind persists and navigates multiple chat sessions.

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
}

// Full session — loaded on demand when opening a chat
struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]

    var meta: ChatSessionMeta { get }   // computed — no duplication
    static func new() -> ChatSession    // creates empty session with UUID
}
```

The split avoids loading all messages into memory just to render the session list.

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
