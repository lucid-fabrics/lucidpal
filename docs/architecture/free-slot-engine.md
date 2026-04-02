---
sidebar_position: 9
---

# CalendarFreeSlotEngine

A pure static algorithm that finds available time slots in a user's calendar. Zero dependencies on EventKit — fully testable in isolation.

## Purpose

`CalendarFreeSlotEngine` separates the *slot-finding logic* from the *calendar data access layer*. `CalendarActionController` fetches busy windows from `CalendarService` (EventKit) and hands them to the engine; the engine knows nothing about EventKit.

```swift
enum CalendarFreeSlotEngine {
    static func findSlots(
        busyWindows: [(start: Date, end: Date)],
        rangeStart: Date,
        rangeEnd: Date,
        duration: TimeInterval
    ) -> [CalendarFreeSlot]
}
```

## Input

| Parameter | Type | Description |
|-----------|------|-------------|
| `busyWindows` | `[(start: Date, end: Date)]` | Pre-merged, sorted busy intervals. All-day events are excluded before this point. |
| `rangeStart` | `Date` | Start of the search window (e.g. now). |
| `rangeEnd` | `Date` | End of the search window (e.g. +7 days). |
| `duration` | `TimeInterval` | Minimum length required for a slot to qualify. |

### All-day Event Handling

All-day events are excluded from `busyWindows` **before** the call. They are never passed to the engine. This means an all-day event does not block free-slot detection — the user's working hours on that day are still considered available.

## Output

```swift
struct CalendarFreeSlot {
    let start: Date
    let end: Date
}
```

Returns up to **5** `CalendarFreeSlot` values. Each slot starts at the cursor position and ends exactly `duration` seconds later. The engine stops as soon as 5 slots are found or the search window is exhausted.

## Working Hours

| Constant | Source | Default |
|----------|--------|---------|
| Day start | `ChatConstants.defaultWorkdayStartHour` | 8 AM |
| Day end | `ChatConstants.defaultWorkdayEndHour` | 8 PM |
| Days | Weekdays only | Mon–Fri |

Working hours are read from `ChatConstants` — change those values to adjust the window app-wide.

## Algorithm: Timeline Sweep

```
rangeStart                                             rangeEnd
│                                                           │
▼  Mon 8am        Mon 8pm  Tue 8am            Tue 8pm      ▼
┌──────────────────┐        ┌──────────────────────────────┐
│  working window  │  skip  │      working window          │
└──────────────────┘  wknd  └──────────────────────────────┘
      │──busy──│                   │──busy──│
cursor→        →cursor              →       →cursor
      free gap?                    free gap?
```

**Pseudocode:**

1. Set `cursor = nextWeekdayStart(from: rangeStart)` — snaps to 8 AM on the next weekday.
2. While `cursor < rangeEnd` and `slots.count < 5`:
   a. Skip weekends (advance to next Mon 8 AM).
   b. Compute `workEnd` = 8 PM on the cursor's day.
   c. Advance `busyIdx` past any intervals that have already ended before `cursor`.
   d. `freeUntil = min(nextBusyStart, workEnd)`.
   e. If `freeUntil − cursor ≥ duration` → emit slot `[cursor, cursor+duration)`, advance cursor by duration.
   f. Else if the next busy window starts before `workEnd` → jump cursor past that busy window's end.
   g. Else → advance to next weekday's 8 AM.

The `busyIdx` pointer only ever moves forward — O(n) over the busy windows per day.

## Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| Back-to-back events | `busyIdx` advances past consecutive intervals; cursor jumps to the end of the last one |
| Event spanning midnight | Treated as ending at or after `workEnd`; cursor advances to next weekday |
| Empty day (no events) | `nextBusyStart = rangeEnd`; the entire working window is considered free |
| Weekend in range | `nextWeekdayStart` skips Saturday (weekday 7) and Sunday (weekday 1), with a safety limit of 8 iterations to prevent infinite loops |
| `duration = 0` or `rangeStart ≥ rangeEnd` | Returns empty array immediately (guard at top of `findSlots`) |
| Fewer than 5 slots available | Returns however many were found |

## Key Types

```swift
// Output value — one candidate time window
struct CalendarFreeSlot {
    let start: Date
    let end: Date
}

// Constants used by the engine
enum ChatConstants {
    static let defaultWorkdayStartHour = 8   // 8 AM
    static let defaultWorkdayEndHour   = 20  // 8 PM
}
```

## Caller Contract

`CalendarActionController` is responsible for:

1. Fetching all events in the requested date range via `CalendarService`.
2. **Filtering out all-day events** before building `busyWindows`.
3. **Sorting and merging** overlapping intervals so `busyWindows` is a clean sorted list.
4. Calling `CalendarFreeSlotEngine.findSlots(...)`.
5. Wrapping results in a `CalendarFreeSlotCard` for display.

The engine makes no assumptions about overlap merging — that is the caller's responsibility.

## See Also

- [Calendar Integration](./calendar.md) — end-to-end flow, action block format, confirmation UI
