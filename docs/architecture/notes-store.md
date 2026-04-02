---
title: NotesStore
sidebar_label: NotesStore
---

# NotesStore

`NotesStore` is the single source of truth for all user notes. It persists an in-memory array to a JSON file on disk and exposes a simple CRUD + search surface via `NotesStoreProtocol`.

---

## NoteItem Model

`NoteItem` is a value type (`struct`) that is `Identifiable`, `Codable`, `Equatable`, and `Sendable`.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Stable identifier, set on creation |
| `title` | `String` | Short title of the note |
| `body` | `String` | Full note text |
| `tags` | `[String]` | Free-form user tags |
| `createdAt` | `Date` | Immutable creation timestamp |
| `updatedAt` | `Date` | Updated by `save(_:)` on every write |
| `aiSummary` | `String?` | AI-generated one-sentence summary |
| `aiActionItems` | `[String]` | AI-extracted action items (empty array by default) |
| `aiCategory` | `NoteCategory?` | AI-assigned category (nil until enriched) |
| `source` | `NoteSource` | How the note was created (default `.manual`) |
| `isPinned` | `Bool` | Whether the note is pinned (default `false`) |

The `Codable` implementation uses `decodeIfPresent` with safe defaults for all AI fields and `source`/`isPinned`, ensuring backward compatibility when older persisted files lack those keys.

---

## NoteCategory Enum

`NoteCategory: String, Codable, CaseIterable, Sendable`

| Case | Icon | Label |
|------|------|-------|
| `.idea` | 💡 | Idea |
| `.task` | ✅ | Task |
| `.journal` | 📓 | Journal |
| `.health` | 🏥 | Health |
| `.goal` | 🎯 | Goal |
| `.memory` | 🧠 | Memory |
| `.finance` | 💰 | Finance |
| `.other` | 📝 | Note |

---

## NoteSource Enum

`NoteSource: String, Codable, Sendable`

| Case | SF Symbol | Origin |
|------|-----------|--------|
| `.manual` | `pencil` | User typed directly |
| `.conversation` | `bubble.left.and.bubble.right` | Saved from a chat session |
| `.voice` | `mic.fill` | Voice dictation |
| `.photo` | `camera.fill` | Captured via photo/vision |
| `.siri` | `waveform` | Created via Siri/`SaveNoteIntent` |

---

## Storage Layout

| Property | Value |
|----------|-------|
| Filename | `lucidpal_notes.json` |
| Directory | `NSDocumentDirectory` (user domain) |
| Fallback | `NSTemporaryDirectory` if Documents unavailable |
| Format | JSON array of `NoteItem` objects |
| Write options | `.atomic` + `.completeFileProtection` |
| Max notes | 500 (oldest note evicted when cap is reached) |

The filename constant `notesStoreFilename` is shared between the main app and `SaveNoteIntent` so both targets write to the same file.

---

## CRUD Operations

### Create / Update — `save(_ note: NoteItem)`

- If a note with the same `id` exists → updates in place and stamps `updatedAt = .now`.
- If the note is new → inserts at index 0 (most-recent-first order).
- If the store is at capacity (500 notes) → removes the last (oldest) entry before inserting.
- Calls `persist()` after every mutation.

### Delete — `delete(id: UUID)`

Removes all notes matching the given `id` (at most one, since IDs are unique) then calls `persist()`.

### Pin / Unpin

There is no dedicated pin method. Callers toggle `note.isPinned` then call `save(_:)`. The store treats pinning like any other field update.

---

## Search

`search(query: String) -> [NoteItem]`

- **In-memory** — operates on the live `notes` array; no file I/O.
- Case-insensitive substring match across `title`, `body`, and each element of `tags`.
- Returns all matching notes in their current sort order (insertion order, newest first).

---

## NotesStoreProtocol

```swift
@MainActor
protocol NotesStoreProtocol: AnyObject {
    var notes: [NoteItem] { get }
    func save(_ note: NoteItem)
    func delete(id: UUID)
    func search(query: String) -> [NoteItem]
}
```

The protocol is annotated `@MainActor`, so all conformers and callers must run on the main actor. This keeps mutation and UI observation on a single actor without explicit locking.

Views and view models depend on the protocol, not the concrete type, enabling injection of a mock store in tests.

---

## Reactive Update Pattern

`NotesStore` is a `@MainActor final class`. The `notes` property is declared `private(set) var`, so external observers cannot mutate it directly.

Because `NotesStore` is consumed by `@Observable` or `ObservableObject` view models, any call to `save(_:)` or `delete(id:)` mutates `notes` on the main actor, which triggers SwiftUI view invalidation automatically when the view model exposes `notes` as a published/observable property.

There are no `@Published` wrappers inside `NotesStore` itself; reactivity is delegated to whichever view model holds the store reference.

---

## NotePreview

`NotePreview` is a compact snapshot stored in `ChatMessage` for rendering note cards inside a conversation without embedding the full note body.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Matches the source `NoteItem.id` |
| `title` | `String` | Note title |
| `snippet` | `String` | First 200 characters of `body` |
| `state` | `NotePreviewState` | `.created`, `.updated`, `.deleted`, `.searchResult` |

---

## Relationship to NoteEnrichmentService

After `save(_:)` is called with a new note, `NoteEnrichmentService` asynchronously enriches it with AI metadata (`aiSummary`, `aiActionItems`, `aiCategory`). Enrichment results are written back through another `save(_:)` call, updating the existing note in place.

See [NoteEnrichmentService architecture](./note-enrichment.md) for the full enrichment pipeline.
