---
sidebar_position: 3
---

# Calendar Integration

How LucidPal translates natural language into EventKit operations.

## End-to-End Flow

```
User: "Add dentist Friday at 10am, remind me 30 min before"
          ↓
LLM generates CALENDAR_ACTION block:
[CALENDAR_ACTION:{"action":"create","title":"Dentist",
  "start":"2026-03-20T10:00:00","end":"2026-03-20T11:00:00",
  "reminderMinutes":30}]
          ↓
ChatViewModel.executeCalendarActions() detects block
          ↓
CalendarActionController.execute(json:) → CalendarActionResult
          ↓
CalendarService.createEvent(...) → EventKit EKEventStore
          ↓
CalendarEventPreview shown as card in chat
          ↓
User taps "Confirm" → event created
```

## Action Block Format

The LLM is instructed (via system prompt) to output structured JSON wrapped in a recognizable tag:

```
[CALENDAR_ACTION:{...JSON...}]
```

### Supported Actions

<details>
<summary>create</summary>

```json
{
  "action": "create",
  "title": "Team Meeting",
  "start": "2026-03-20T14:00:00",
  "end": "2026-03-20T15:00:00",
  "location": "Zoom",
  "notes": "Weekly sync",
  "reminderMinutes": 15,
  "isAllDay": false,
  "recurrence": "weekly",
  "recurrenceEnd": "2026-06-01T00:00:00"
}
```

</details>

<details>
<summary>update</summary>

```json
{
  "action": "update",
  "search": "Team Meeting",
  "title": "Weekly Review",
  "start": "2026-03-20T15:00:00"
}
```

Only include fields you want to change. `search` must match the exact event title.

</details>

<details>
<summary>delete</summary>

```json
{ "action": "delete", "search": "Dentist" }
```

Or delete a date range:

```json
{
  "action": "delete",
  "start": "2026-03-23T00:00:00",
  "end": "2026-03-23T23:59:59"
}
```

</details>

<details>
<summary>list</summary>

```json
{
  "action": "list",
  "start": "2026-03-17T00:00:00",
  "end": "2026-03-21T23:59:59"
}
```

Returns a list of `CalendarEventPreview` cards in the chat.

</details>

<details>
<summary>query (free slots)</summary>

```json
{
  "action": "query",
  "start": "2026-03-17T00:00:00",
  "end": "2026-03-21T23:59:59",
  "durationMinutes": 60
}
```

Returns available time windows via `CalendarFreeSlotEngine`.

</details>

## Confirmation Flow

All destructive or mutating actions go through a **two-step confirmation** UI:

```
LLM outputs action block
        ↓
CalendarEventPreview created with state = .pendingDeletion / .pendingUpdate
        ↓
Card shown with [Keep] / [Delete] or [Cancel] / [Apply] buttons
        ↓
User taps confirm → ChatViewModel.confirmDeletion() or confirmUpdate()
        ↓
CalendarService executes → preview.state = .deleted / .updated / .rescheduled
```

### Preview States

| State | Meaning |
|-------|---------|
| `.created` | Event successfully created — tap to open in Calendar |
| `.pendingDeletion` | Awaiting user confirmation to delete |
| `.deleted` | Deleted — shows strikethrough + Undo button |
| `.deletionCancelled` | User kept the event |
| `.pendingUpdate` | Awaiting user confirmation to apply changes |
| `.updated` | Updated in place |
| `.rescheduled` | Start/end times changed |
| `.updateCancelled` | User dismissed the update |
| `.restored` | Event recreated after undo |

## Anti-Corruption Layer

`CalendarService` never exposes `EKEvent` or `EKCalendar` to the ViewModel layer. All EventKit types are mapped to domain structs at the service boundary:

```swift
// Domain type — no EventKit import needed above service layer
struct CalendarInfo: Identifiable, Hashable, Sendable {
    let id: String      // EKCalendar.calendarIdentifier
    let title: String
}
```

## Conflict Detection

When creating or updating an event, `CalendarService` checks for overlapping events in the same time window:

```swift
func findConflicts(start: Date, end: Date, excludingIdentifier: String? = nil) -> [CalendarEventInfo]
```

If conflicts exist, `CalendarEventPreview.hasConflict = true` and an orange `⚠` badge is shown on the card.

## CalendarFreeSlotEngine

A **pure static algorithm** with zero dependencies — fully testable without EventKit:

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

`CalendarActionController` fetches busy windows from `CalendarService` and passes them to the engine. The engine returns available slots that fit the requested duration.

For a deep-dive into the sweep algorithm, working hours defaults, all-day event handling, and edge cases, see [CalendarFreeSlotEngine](./free-slot-engine.md).
