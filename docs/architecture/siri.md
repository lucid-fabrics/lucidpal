---
sidebar_position: 5
---

# Siri & Shortcuts

How LucidPal integrates with Siri using the AppIntents framework.

## Overview

LucidPal registers nine Siri intents via the **AppIntents** framework. Calendar and AI intents use a **handoff pattern**: they store a pending query in `UserDefaults`, tell Siri a brief spoken confirmation, and open the app. The app picks up the pending query when its scene becomes active. The three background-action intents — `SaveNoteIntent`, `FindContactIntent`, and `LogHabitIntent` — run entirely without opening the app (`openAppWhenRun: false`) and write directly to the app's shared document storage.

```
User: "Add dentist Friday at 10am to LucidPal"
        ↓
AddCalendarEventIntent.perform()
        ↓
UserDefaults["pm_siri_pending_query"] = "Add dentist Friday at 10am to my calendar"
        ↓
return .result(dialog: "Opening LucidPal to add dentist Friday at 10am.")
        ↓
App foregrounds → LucidPalApp reads UserDefaults key
        ↓
SessionListViewModel.handleSiriQuery(_:) → new session → ChatViewModel.sendMessage()
        ↓
LLM generates CALENDAR_ACTION block → CalendarEventPreview shown
```

## Intent Inventory

| Intent                      | Pattern     | Trigger phrases                                                                                 | Pre-seeded query                | User parameter                 |
| --------------------------- | ----------- | ----------------------------------------------------------------------------------------------- | ------------------------------- | ------------------------------ |
| `AskLucidPalIntent`         | handoff     | "Ask LucidPal [question]"                                                                       | User-provided `query`           | `@Parameter query: String`     |
| `CheckCalendarIntent`       | handoff     | "Check my LucidPal calendar"                                                                    | "What's on my calendar today?"  | —                              |
| `AddCalendarEventIntent`    | handoff     | "Add [event] to LucidPal"                                                                       | "Add [event] to my calendar"    | `@Parameter event: String`     |
| `FindFreeTimeIntent`        | handoff     | "Find free time in LucidPal"                                                                    | "Find a free 1-hour slot today" | —                              |
| `DeleteCalendarEventIntent` | handoff     | "Delete [event] in LucidPal"                                                                    | —                               | `@Parameter eventName: String` |
| `UndoLastDeletionIntent`    | handoff     | "Undo my last LucidPal action", "Undo what I just did in LucidPal", "Undo last LucidPal change" | —                               | —                              |
| `SaveNoteIntent`            | background  | "Save note to LucidPal", "Add note to LucidPal", "Jot down in LucidPal"                        | —                               | `@Parameter title: String`, `@Parameter content: String` |
| `FindContactIntent`         | background  | "Find contact in LucidPal", "Look up contact in LucidPal", "Get phone number from LucidPal"    | —                               | `@Parameter name: String`      |
| `LogHabitIntent`            | background  | "Log habit in LucidPal", "Track habit with LucidPal", "Log my workout in LucidPal"             | —                               | `@Parameter habitName: String`, `@Parameter value: Double` |

## Handoff Key

All intents write to the same `UserDefaults` key:

```swift
UserDefaults.standard.set(query, forKey: "pm_siri_pending_query")
```

`LucidPalApp` reads and clears this key when the scene activates. The query is cleared immediately after forwarding to prevent replaying on subsequent launches.

## Audio Feedback (`ProvidesDialog`)

Every intent conforms to `ProvidesDialog`, giving Siri a spoken response:

```swift
func perform() async throws -> some IntentResult & ProvidesDialog {
    // ...store pending query...
    return .result(dialog: "Opening LucidPal.")
}
```

Without `ProvidesDialog`, Siri would show a generic "Done" card with no audio confirmation.

## AppShortcutsProvider

`LucidPalShortcuts` registers suggested phrases with the system (iOS 16.4+). Phrases use `.applicationName` interpolation so they survive app renames:

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

## Navigation & Pre-fill Mechanism

After a Siri handoff intent fires, `LucidPalApp` reads the `UserDefaults` key and calls `SessionListViewModel.scheduleSiriQuery(_:)`. This method:

1. Creates a new `ChatSession` and saves it via `SessionManager`.
2. Stores the query string in `pendingQueryBySessionID[session.id]`.
3. Sets `siriNavigationMeta = session.meta` — a `@Published ChatSessionMeta?` on `SessionListViewModel`.

`SessionListView` observes `siriNavigationMeta` to navigate to the new session. `ChatSessionContainer` reads `pendingQueryBySessionID[session.id]` and pre-fills the text field (or auto-sends the message), then removes the entry.

The same `pendingQueryBySessionID` mechanism is also used by in-app quick-action chips that want to pre-seed a new session with a fixed prompt.

```swift
// SessionListViewModel
@Published var siriNavigationMeta: ChatSessionMeta?
var pendingQueryBySessionID: [UUID: String] = [:]

func scheduleSiriQuery(_ query: String) {
    let session = ChatSession.new()
    sessionManager.save(session)
    pendingQueryBySessionID[session.id] = query
    siriNavigationMeta = session.meta
}
```

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

| Method  | Signature                         | Description                                   |
| ------- | --------------------------------- | --------------------------------------------- |
| `write` | `write(_ action: SiriLastAction)` | Encodes and persists the action               |
| `read`  | `read() -> SiriLastAction?`       | Decodes and returns the last action, or `nil` |
| `clear` | `clear()`                         | Removes the stored value                      |

### Write sites

| Call site                                              | Action type written                                            |
| ------------------------------------------------------ | -------------------------------------------------------------- |
| `CalendarActionController.createEvent()`               | `.created` (after EKEvent is saved)                            |
| `ChatViewModel+CalendarConfirmation.confirmDeletion()` | `.deleted` (after user confirms delete card)                   |
| `ChatViewModel+CalendarConfirmation.confirmUpdate()`   | `.updated` or `.rescheduled` (after user confirms update card) |

### UndoLastDeletionIntent behaviour

`UndoLastDeletionIntent.perform()` reads `SiriContextStore.read()` then branches on `type`:

| Type                        | Behaviour                                                                   |
| --------------------------- | --------------------------------------------------------------------------- |
| `.deleted`                  | Recreates the event via `CalendarService`; asks user to confirm first       |
| `.created`                  | Deletes the event using `eventIdentifier`; asks user to confirm first       |
| `.updated` / `.rescheduled` | Returns a dialog informing the user that undo of edits is not yet supported |
| `nil` (nothing stored)      | Returns a dialog stating there is no recent action to undo                  |
