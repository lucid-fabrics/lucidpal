---
sidebar_position: 13
---

# HabitStore

How LucidPal persists habit definitions and tracks daily completions.

## Data Model

Two structs form the persistence layer:

```swift
struct HabitDefinition: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var emoji: String
    var unit: HabitUnit          // .boolean | .count | .duration
    var targetValue: Double      // e.g. 1 for boolean, 8 for "glasses of water"
    var frequency: HabitFrequency // .daily | .weekly
    var colorHex: String
    var createdAt: Date
    var isArchived: Bool
}

struct HabitEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let habitID: UUID            // FK → HabitDefinition.id
    var value: Double            // logged amount (1.0 for boolean completion)
    let date: Date
    var note: String?
}
```

`HabitDefinition` describes _what_ to track; `HabitEntry` records _that_ it was tracked on a specific date. There is no enforced foreign-key constraint — the relationship is maintained by matching `habitID`.

`HabitDefinition` uses a custom `init(from:)` decoder with `decodeIfPresent` for `isArchived` so older JSON written before the field existed decodes cleanly (defaults to `false`).

### Units and targets

| Unit | Meaning | Completion condition |
|---|---|---|
| `.boolean` | Done / not done | `entry.value >= 1` |
| `.count` | Numeric repetitions (reps, glasses) | `entry.value >= targetValue` |
| `.duration` | Minutes | `entry.value >= targetValue` |

## Storage Layout

```
Documents/
├── lucidpal_habits.json                ← [HabitDefinition] array (all habits, including archived)
├── lucidpal_entries_2025-03.json       ← [HabitEntry] for March 2025
├── lucidpal_entries_2025-04.json       ← [HabitEntry] for April 2025
└── lucidpal_entries_YYYY-MM.json       ← one file per calendar month
```

The habits file is a flat JSON array. Entry files are also flat arrays, sharded by month — the filename encodes the year and month as `YYYY-MM`. All writes use `.atomic` and `.completeFileProtection` for crash-safety and data-at-rest encryption.

### In-memory cache

`HabitStore` maintains an `entryCache: [String: [HabitEntry]]` keyed by month string (e.g. `"2025-04"`). `loadEntries(for:)` returns from the cache on a hit and writes the decoded array on a miss. `persistEntries(_:for:)` updates both the cache and disk atomically so the two never diverge within a session.

## CRUD Operations

### Habit definitions

| Operation | Method | Notes |
|---|---|---|
| Create | `save(_:)` | Appends if ID is new; enforces 100-habit cap (active habits only) |
| Update | `save(_:)` | Replaces in-place by matching `id` |
| Archive | `save(_:)` with `isArchived = true` | Soft-delete; archived habits remain in the JSON file |
| Hard delete | `delete(id:)` | Removes from the array entirely; entries remain on disk |

### Log entries

`logEntry(_:)` implements upsert semantics: before appending the new entry it removes any existing entry for the same `(habitID, day)` pair. This means re-logging a habit on the same day replaces the earlier value rather than duplicating it.

`deleteEntry` is not exposed on the protocol; removal is implicit via re-logging.

## Query Methods

### `entries(for:in:)`

Returns all entries for a given habit in a single month. Delegates to `loadEntries(for:)` — single file read with cache.

### `todayEntry(for:)`

Loads today's month file and finds the first entry matching `habitID` that `isDateInToday`. Returns `nil` if not yet logged.

### `recentEntries(for:days:)`

Scans multiple month files to cover the requested window:

```
monthsNeeded = max(2, (days / 28) + 2)
```

For each month offset (0 … monthsNeeded−1) it loads that month's entries from cache and filters by `habitID`. After collecting all candidates it applies a cutoff (`startOfDay(today − days)`) and returns sorted ascending.

### `todayCompletionSummary()`

Returns `(done: Int, total: Int)` for all active (non-archived) habits. Calls `todayEntry(for:)` per habit and checks the unit-specific completion condition.

### `bestStreak(for:)`

Scans up to 24 months of history. Collects the set of distinct `startOfDay` dates on which an entry exists, sorts them, then walks consecutive pairs:

```
diff = dateComponents(.day, from: sorted[i-1], to: sorted[i]).day
if diff == 1  → current += 1; best = max(best, current)
else          → current = 1
```

Returns the longest consecutive-day run found.

### `completionRate(for:days:)`

```
rate = loggedDays / totalDays
```

Where `loggedDays` is the number of distinct calendar days with an entry in the window, and `totalDays` is clamped to the smaller of `days` and `daysSinceCreation + 1` so habits created recently don't show artificially low rates.

## Streak Algorithm

`streak(for:)` computes the _current_ streak (running up to today):

1. Start at `startOfDay(now)`.
2. Loop up to 365 times (safety cap):
   - Load the month file for `checkDate` (cache hit for the current month).
   - If an entry exists for that day → `streak += 1`.
   - If no entry and `checkDate` is today → skip (today may not be logged yet; don't break).
   - If no entry and `checkDate` is not today → break.
3. Advance `checkDate` back one day and repeat.

The "skip today if not yet logged" rule means a user who logs yesterday but hasn't logged yet today still sees a non-zero streak.

## Month File Scanning

Multi-month queries (`recentEntries`, `bestStreak`) compute a list of month offsets and call `loadEntries(for:)` for each. The cache keyed by `"YYYY-MM"` string ensures each unique month file is read from disk at most once per session, regardless of how many queries reference it.

A `seen: Set<String>` guard in `recentEntries` prevents double-loading the same month when the offset arithmetic produces duplicates at boundaries.

## HabitStoreProtocol

```swift
@MainActor
protocol HabitStoreProtocol: AnyObject {
    var habits: [HabitDefinition] { get }
    func save(_ habit: HabitDefinition)
    func delete(id: UUID)
    func logEntry(_ entry: HabitEntry)
    func entries(for habitID: UUID, in month: Date) -> [HabitEntry]
    func todayEntry(for habitID: UUID) -> HabitEntry?
    func streak(for habitID: UUID) -> Int
    func recentEntries(for habitID: UUID, days: Int) -> [HabitEntry]
    func todayCompletionSummary() -> (done: Int, total: Int)
    func bestStreak(for habitID: UUID) -> Int
    func completionRate(for habitID: UUID, days: Int) -> Double
}
```

The protocol exists primarily to support unit testing. ViewModels and the LLM tool layer depend on `HabitStoreProtocol`, not `HabitStore`, so tests can inject a `MockHabitStore` that holds an in-memory array without touching the file system. The mock implements the full protocol surface with simple array mutations and fixed return values, making habit-related view model tests hermetic and fast.

## Thread Safety

`HabitStore` is annotated `@MainActor`. Every method — including private persistence helpers — runs on the main actor. This means:

- No concurrent writes to `entryCache` or `habits`.
- No concurrent reads interleaved with writes.
- `@Published var habits` changes fire on the main thread, satisfying SwiftUI's requirements.

There is no background I/O dispatch. File reads and writes occur synchronously on the main actor. Given typical habit file sizes (tens to low hundreds of entries per month), the latency is negligible.
