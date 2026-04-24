---
sidebar_position: 5
---

# Siri & Shortcuts

How LucidPal integrates with Siri using the AppIntents framework.

## Overview

LucidPal registers eleven Siri intents via the **AppIntents** framework. Calendar and AI intents use a **handoff pattern**: they store a pending query in `UserDefaults`, tell Siri a brief spoken confirmation, and open the app. The app picks up the pending query when its scene becomes active. Five background-action intents — `SaveNoteIntent`, `FindContactIntent`, `LogHabitIntent`, `SetReminderIntent`, and `DeleteCalendarEventIntent` — run entirely without opening the app (`openAppWhenRun: false`) and write directly to the app's shared document storage.

```
User: "Add dentist Friday at 10am to LucidPal"
        ↓
AddCalendarEventIntent.perform()
        ↓
UserDefaults["pm_siri_pending_event"] = "Add dentist Friday at 10am"
        ↓
return .result(dialog: "Opening LucidPal to add dentist Friday at 10am.")
        ↓
App foregrounds → LucidPalApp reads UserDefaults key
        ↓
SessionListViewModel.handleSiriEvent() → CreateEventSheet shown
        ↓
User confirms → CalendarService.createEvent() → EKEventStore
```

## Intent Inventory

| Intent | Pattern | Trigger phrases | User parameter |
|---|---|---|---|
| `StartVoiceIntent` | handoff | "Talk to LucidPal", "Open LucidPal voice", "Start LucidPal voice", "Listen with LucidPal" | — (sets `pendingVoiceStart` flag) |
| `AskLucidPalIntent` | handoff | "Ask LucidPal [question]" | `@Parameter query: String` |
| `CheckCalendarIntent` | handoff | "Check my LucidPal calendar", "What's on my LucidPal calendar" | — |
| `AddCalendarEventIntent` | handoff | "Add [event] to LucidPal" | `@Parameter event: String` |
| `FindFreeTimeIntent` | handoff | "Find free time in LucidPal" | — |
| `DeleteCalendarEventIntent` | background | "Delete [event] in LucidPal", "Delete event in LucidPal" | `@Parameter eventName: String` |
| `UndoLastDeletionIntent` | handoff | "Undo my last LucidPal action", "Undo what I just did in LucidPal" | — |
| `AgentTaskIntent` | handoff | "Ask LucidPal Agent" | `@Parameter task: String` |
| `SaveNoteIntent` | background | "Save note to LucidPal", "Add note to LucidPal" | `@Parameter title: String`, `@Parameter content: String` |
| `FindContactIntent` | background | "Find contact in LucidPal", "Get phone number from LucidPal" | `@Parameter name: String` |
| `LogHabitIntent` | background | "Log habit in LucidPal", "Log my workout in LucidPal" | `@Parameter habitName: String`, `@Parameter value: Double` |
| `SetReminderIntent` | background | "Set reminder in LucidPal" | `@Parameter title: String`, `@Parameter body: String?`, `@Parameter at: Date` |

## Handoff Keys

Most intents write to `UserDefaults` and are consumed when the scene activates:

| Key | Intent | Consumer |
|---|---|---|
| `pm_siri_pending_query` | `AskLucidPalIntent` | `consumePendingSiriQuery()` → `scheduleSiriQuery()` |
| `pm_siri_pending_event` | `AddCalendarEventIntent` | `consumePendingSiriEvent()` → `scheduleCreateEvent()` |
| `pm_pending_agent_task` | `AgentTaskIntent` | `consumePendingAgentTask()` → `agentViewModel.submitTask()` |
| `pm_pending_voice_start` | `StartVoiceIntent` | `consumePendingVoiceStart()` → `scheduleVoiceSession()` |

`UndoLastDeletionIntent` reads from `SiriContextStore` (a separate `UserDefaults` key) which records the last calendar action with full event data for proper undo.

Keys are cleared immediately after forwarding to prevent replaying on subsequent launches.

### StartVoiceIntent Flow

`StartVoiceIntent` is unique — it opens the app and starts the microphone without requiring a text query:

```swift
// StartVoiceIntent.perform()
UserDefaults.standard.set(true, forKey: "pm_pending_voice_start")

// LucidPalApp.consumePendingVoiceStart()
sessionListViewModel.scheduleVoiceSession()

// SessionListViewModel.scheduleVoiceSession()
// Creates a new session, sets pendingVoiceSessionMeta

// SessionListView watches pendingVoiceSessionMeta
// Sets pendingVoiceSessionID = meta.id, pushes onto navigation stack
// ChatSessionContainer receives startWithVoice: true → mic auto-starts
```

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
        "What's on my \(.applicationName) schedule",
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

| Method | Signature | Description |
|---|---|---|
| `write` | `write(_ action: SiriLastAction)` | Encodes and persists the action |
| `read` | `read() -> SiriLastAction?` | Decodes and returns the last action, or `nil` |
| `clear` | `clear()` | Removes the stored value |

### Write sites

| Call site | Action type written |
|---|---|
| `CalendarActionController.createEvent()` | `.created` (after EKEvent is saved) |
| `ChatViewModel+CalendarConfirmation.confirmDeletion()` | `.deleted` (after user confirms delete card) |
| `ChatViewModel+CalendarConfirmation.confirmUpdate()` | `.updated` or `.rescheduled` (after user confirms update card) |

### UndoLastDeletionIntent behaviour

`UndoLastDeletionIntent.perform()` reads `SiriContextStore.read()` then branches on `type`:

| Type | Behaviour |
|---|---|
| `.deleted` | Recreates the event via `CalendarService`; asks user to confirm first |
| `.created` | Deletes the event using `eventIdentifier`; asks user to confirm first |
| `.updated` / `.rescheduled` | Returns a dialog informing the user that undo of edits isn't supported yet |
| `nil` (nothing stored) | Returns a dialog stating there is no recent action to undo |