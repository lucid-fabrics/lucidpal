---
sidebar_position: 14
---

# Widget Data Flow

How LucidPal passes habit and note data from the main app to the widget extension via an App Group shared container.

---

## App Group

| Property | Value |
|----------|-------|
| App Group ID | `group.app.lucidpal` |
| Snapshot file | `lucidpal_widget_snapshot.json` in the container root |

Both the main app target and the widget extension must have the `group.app.lucidpal` entitlement. The container is accessed via `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`.

---

## WidgetSnapshot Model

`WidgetSnapshot` is a `Codable` struct written and read by both the main app and the widget extension.

| Field | Type | Description |
|-------|------|-------------|
| `writtenAt` | `Date` | Timestamp of the last write; used by the widget to detect stale data |
| `habitsToday` | `Int` | Number of habits completed today |
| `habitsTotal` | `Int` | Total number of active (non-archived) habits |
| `topStreakName` | `String?` | Name of the habit with the longest active streak; `nil` if no active streaks |
| `topStreakDays` | `Int` | Day count of `topStreakName`'s streak; `0` if none |
| `pinnedNote` | `String?` | Title of the most recently pinned note; `nil` if no notes are pinned |

---

## Write Triggers

Two writers update their respective fields in the snapshot:

### WidgetSnapshotWriter.writeHabits(...)

Called by `HabitStore` after:

| HabitStore method | Trigger reason |
|-------------------|----------------|
| `save(_:)` | Habit created or updated (including archive) |
| `logEntry(_:)` | Completion logged — changes `habitsToday` count |
| `delete(id:)` | Habit removed — changes `habitsTotal` count |

Updates fields: `writtenAt`, `habitsToday`, `habitsTotal`, `topStreakName`, `topStreakDays`.

### WidgetSnapshotWriter.writeNote(pinnedNote:)

Called by `NoteActionController` after:

| NoteActionController operation | Trigger reason |
|-------------------------------|----------------|
| Note created | A new pinned or unpinned note may shift the pinned candidate |
| Note updated | Pin/unpin state or title may have changed |

Updates fields: `writtenAt`, `pinnedNote`.

---

## Merge Behavior

Each writer uses a **read-modify-write** pattern to avoid clobbering fields owned by the other writer:

```swift
// Pseudocode
var snapshot = WidgetSnapshotReader.read() ?? WidgetSnapshot()
snapshot.habitsToday = newDone
snapshot.habitsTotal = newTotal
snapshot.topStreakName = topStreak?.habit.name
snapshot.topStreakDays = topStreak?.streak ?? 0
snapshot.writtenAt = .now
WidgetSnapshotWriter.write(snapshot)
```

The write is performed atomically (`.atomic` write option) to prevent the widget from reading a partial file.

---

## Reader

`WidgetSnapshotReader.read()` is called inside the widget extension's `getTimeline(in:completion:)`:

```swift
static func read() -> WidgetSnapshot? {
    guard let url = containerURL else { return nil }
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
}
```

Returns `nil` if the file does not exist (e.g. first launch before any habit or note operation) — widgets handle this by falling back to their empty states.

---

## Widget Refresh

WidgetKit reloads the widget timeline on:

- `.after(eventEnd)` — scheduled entry at the end of each calendar event so the event row disappears on time
- Every **15 minutes** — fallback policy when no event endpoint is imminent

The snapshot is read fresh on **each reload**. There is no in-memory caching inside the widget extension; the JSON file is the single source of truth.

:::note
The widget does not observe file changes in real time. Updates written by the main app appear in the widget only at the next WidgetKit reload. For most use cases (logging a habit, saving a note) the 15-minute maximum delay is acceptable.
:::
