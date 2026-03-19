---
sidebar_position: 5
---

# Siri & Shortcuts

How PocketMind integrates with Siri using the AppIntents framework.

## Overview

PocketMind registers four Siri intents via the **AppIntents** framework. Because on-device inference cannot run inside a Siri extension, the intents use a **handoff pattern**: they store a pending query in `UserDefaults`, tell Siri a brief spoken confirmation, and open the app. The app picks up the pending query when its scene becomes active.

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
