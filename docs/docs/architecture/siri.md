---
sidebar_position: 5
---

# Siri & Shortcuts

How PocketMind integrates with Siri using the AppIntents framework.

## Overview

PocketMind registers six Siri intents via the **AppIntents** framework. Because on-device inference cannot run inside a Siri extension, the intents use a **handoff pattern**: they store a pending query in `UserDefaults`, tell Siri a brief spoken confirmation, and open the app. The app picks up the pending query when its scene becomes active.

```
User: "Add dentist Friday at 10am to PocketMind"
        ↓
AddCalendarEventIntent.perform()
        ↓
UserDefaults["pm_siri_pending_query"] = "Add dentist Friday at 10am to my calendar"
        ↓
return .result(dialog: "Opening PocketMind to add dentist Friday at 10am.")
        ↓
App foregrounds → PocketMindApp reads UserDefaults key
        ↓
SessionListViewModel.handleSiriQuery(_:) → new session → ChatViewModel.sendMessage()
        ↓
LLM generates CALENDAR_ACTION block → CalendarEventPreview shown
```

## Intent Inventory

| Intent | Trigger phrases | Pre-seeded query | User parameter |
|--------|----------------|-----------------|----------------|
| `AskPocketMindIntent` | "Ask PocketMind [question]" | User-provided `query` | `@Parameter query: String` |
| `CheckCalendarIntent` | "Check my PocketMind calendar" | "What's on my calendar today?" | — |
| `AddCalendarEventIntent` | "Add [event] to PocketMind" | "Add [event] to my calendar" | `@Parameter event: String` |
| `FindFreeTimeIntent` | "Find free time in PocketMind" | "Find a free 1-hour slot today" | — |
| `DeleteCalendarEventIntent` | "Delete [event] in PocketMind" | — | `@Parameter eventName: String` |
| `UndoLastDeletionIntent` | "Undo my last PocketMind action", "Undo what I just did in PocketMind", "Undo last PocketMind change" | — | — |

## Handoff Key

All intents write to the same `UserDefaults` key:

```swift
UserDefaults.standard.set(query, forKey: "pm_siri_pending_query")
```

`PocketMindApp` reads and clears this key when the scene activates. The query is cleared immediately after forwarding to prevent replaying on subsequent launches.

## Audio Feedback (`ProvidesDialog`)

Every intent conforms to `ProvidesDialog`, giving Siri a spoken response:

```swift
func perform() async throws -> some IntentResult & ProvidesDialog {
    // ...store pending query...
    return .result(dialog: "Opening PocketMind.")
}
```

Without `ProvidesDialog`, Siri would show a generic "Done" card with no audio confirmation.

## AppShortcutsProvider

`PocketMindShortcuts` registers suggested phrases with the system (iOS 16.4+). Phrases use `.applicationName` interpolation so they survive app renames:

```swift
AppShortcut(
    intent: CheckCalendarIntent(),
    phrases: [
        "Check my \(.applicationName) calendar",
        "What's on my \(.applicationName) calendar",
        "Show my \(.applicationName) schedule"
    ],
    shortTitle: "Check Calendar",
    systemImageName: "calendar"
)
```

On iOS < 16.4, the intents still work but users must add the shortcuts manually via the Shortcuts app.

## SiriContextStore

`SiriContextStore` is a lightweight persistence layer that records the last calendar action taken — whether triggered by Siri or performed inside the app. `UndoLastDeletionIntent` reads from this store to know what to reverse.

### Data model

```swift
struct SiriLastAction: Codable {
    let type: ActionType           // created | deleted | updated | rescheduled
    let eventTitle: String
    let eventStart: Date?
    let eventEnd: Date?
    let calendarName: String
    let calendarIdentifier: String
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let eventIdentifier: String    // EKEvent.eventIdentifier used for undo
    let timestamp: Date
}
```

`ActionType` is a `String` raw-value enum with four cases: `created`, `deleted`, `updated`, `rescheduled`.

### Storage

`SiriContextStore` is a caseless enum with three static methods backed by `UserDefaults` key `"pm_siri_last_action"`. JSON encoding/decoding uses `JSONEncoder` / `JSONDecoder`.

| Method | Signature | Description |
|--------|-----------|-------------|
| `write` | `write(_ action: SiriLastAction)` | Encodes and persists the action |
| `read` | `read() -> SiriLastAction?` | Decodes and returns the last action, or `nil` |
| `clear` | `clear()` | Removes the stored value |

### Write sites

| Call site | Action type written |
|-----------|-------------------|
| `CalendarActionController.createEvent()` | `.created` (after EKEvent is saved) |
| `ChatViewModel+CalendarConfirmation.confirmDeletion()` | `.deleted` (after user confirms delete card) |
| `ChatViewModel+CalendarConfirmation.confirmUpdate()` | `.updated` or `.rescheduled` (after user confirms update card) |

### UndoLastDeletionIntent behaviour

`UndoLastDeletionIntent.perform()` reads `SiriContextStore.read()` then branches on `type`:

| Type | Behaviour |
|------|-----------|
| `.deleted` | Recreates the event via `CalendarService`; asks user to confirm first |
| `.created` | Deletes the event using `eventIdentifier`; asks user to confirm first |
| `.updated` / `.rescheduled` | Returns a dialog informing the user that undo of edits is not yet supported |
| `nil` (nothing stored) | Returns a dialog stating there is no recent action to undo |
