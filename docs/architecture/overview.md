---
sidebar_position: 1
---

# Architecture Overview

MVVM layers, dependency injection, and actor isolation in LucidPal.

## Layer Diagram

```
┌─────────────────────────────────────┐
│           SwiftUI Views             │  ← Layout only, zero business logic
├─────────────────────────────────────┤
│           ViewModels                │  ← @MainActor ObservableObject
│  ChatViewModel  SessionListViewModel│
│  ModelDownloadViewModel  Settings   │
├─────────────────────────────────────┤
│           Services (Protocols)      │  ← Injected as any XProtocol
│  LLMService  CalendarService        │
│  SessionManager  SpeechService      │
│  HapticService  ModelDownloader     │
│  ContactsService  HabitStore        │
├─────────────────────────────────────┤
│         Models / Domain Types       │  ← Pure data, no UIKit/SwiftUI
│  ChatMessage  ChatSession           │
│  CalendarEventPreview  ModelInfo    │
└─────────────────────────────────────┘
```

## Dependency Injection

LucidPal uses **constructor injection** throughout. All service dependencies are declared as protocol existentials (`any XProtocol`), never concrete types.

```swift
// ✅ Correct — protocol existential
final class ChatViewModel: ObservableObject {
    let llmService: any LLMServiceProtocol
    let calendarService: any CalendarServiceProtocol
    let settings: any AppSettingsProtocol
}

// ❌ Wrong — concrete type (untestable, breaks DI)
let llmService: LLMService
```

**`LucidPalApp`** is the sole composition root — the only place concrete services are instantiated:

```swift
@main struct LucidPalApp: App {
    private let llmService = LLMService()
    private let calendarService = CalendarService()
    private let hapticService = HapticService()
    private let contactsService = ContactsService()
    private let habitStore = HabitStore()
    private let noteEnrichmentService = NoteEnrichmentService()
    // noteEnrichmentService injected into NotesListViewModel alongside notesStore
}
```

`LucidPalApp` also observes `UIApplication.willEnterForegroundNotification` to refresh `AppSettings.notificationsEnabled` on every foreground transition, keeping the settings UI in sync with the system permission state.

## Actor Isolation

| Actor        | Purpose                                                                      |
| ------------ | ---------------------------------------------------------------------------- |
| `@MainActor` | All ViewModels and ObservableObjects — guarantees UI updates on main thread  |
| `LlamaActor` | Serial actor wrapping llama.cpp C FFI — serializes inference, safe for async |

```swift
actor LlamaActor {
    // All calls serialized — no data races on C pointers
    func generate(prompt: String) async throws -> String { ... }
}
```

## Protocol Inventory

| Protocol                           | Conforming Type                                 | Mock                           |
| ---------------------------------- | ----------------------------------------------- | ------------------------------ |
| `LLMServiceProtocol`               | `LLMService`                                    | `MockLLMService`               |
| `CalendarServiceProtocol`          | `CalendarService`                               | `MockCalendarService`          |
| `CalendarActionControllerProtocol` | `CalendarActionController`                      | `MockCalendarActionController` |
| `SessionManagerProtocol`           | `SessionManager`                                | `MockSessionManager`           |
| `SpeechServiceProtocol`            | `SpeechService`                                 | `MockSpeechService`            |
| `HapticServiceProtocol`            | `HapticService`                                 | `MockHapticService`            |
| `ChatHistoryManagerProtocol`       | `ChatHistoryManager` / `NoOpChatHistoryManager` | —                              |
| `ModelDownloaderProtocol`          | `ModelDownloader`                               | `MockModelDownloader`          |
| `AppSettingsProtocol`              | `AppSettings`                                   | `MockAppSettings`              |
| `PinnedPromptsStoreProtocol`       | `PinnedPromptsStore`                            | —                              |
| `NotificationServiceProtocol`      | `NotificationService`                           | —                              |
| `LiveActivityServiceProtocol`      | `LiveActivityService`                           | —                              |
| `NotesStoreProtocol`               | `NotesStore`                                    | —                              |
| `ContactsServiceProtocol`          | `ContactsService`                               | —                              |
| `HabitStoreProtocol`               | `HabitStore`                                    | —                              |

> **Note:** `NoteEnrichmentService` is a concrete service (no protocol) — it is injected directly into `NotesListViewModel` for async LLM-driven note enrichment.

## File Structure

```
Sources/
├── App/
│   ├── LucidPalApp.swift       ← @main, composition root
│   ├── ContentView.swift         ← Root navigation (onboarding → sessions)
│   └── AppDelegate.swift         ← UIApplicationDelegate (background tasks)
├── Models/
│   ├── ChatMessage.swift         ← Message struct, CalendarEventPreview
│   ├── ChatSession.swift         ← Session and SessionMeta types
│   ├── CalendarActionModels.swift← Payload and result types
│   ├── ConversationTemplate.swift← Template definitions for system prompts
│   ├── PinnedPrompt.swift        ← Pinned prompt data model
│   ├── LucidPalActivityAttributes.swift ← Live Activity attributes
│   ├── ModelInfo.swift           ← GGUF model metadata
│   └── NoteItem.swift            ← Note model with AI metadata fields
├── Services/
│   ├── LLMService.swift          ← Model load/unload, streaming
│   ├── LlamaActor.swift          ← llama.cpp serial actor
│   ├── CalendarService.swift     ← EventKit abstraction
│   ├── CalendarActionController.swift ← LLM JSON → calendar action
│   ├── CalendarFreeSlotEngine.swift   ← Pure slot-finding algorithm
│   ├── SessionManager.swift      ← Multi-session persistence
│   ├── HapticService.swift       ← UIImpactFeedbackGenerator wrapper
│   ├── LiveActivityService.swift ← Live Activity start/update/end
│   ├── NotificationService.swift ← UNUserNotificationCenter wrapper
│   ├── PinnedPromptsStore.swift  ← Pinned prompts persistence
│   ├── ContactsService.swift     ← Contacts framework abstraction
│   ├── ContactsServiceProtocol.swift ← Protocol for contacts access
│   ├── HabitStore.swift          ← Habit log persistence (ObservableObject)
│   ├── HabitStoreProtocol.swift  ← Protocol for habit store
│   └── NoteEnrichmentService.swift ← Async LLM enrichment for notes
├── ViewModels/
│   ├── ChatViewModel.swift       ← Core message/stream logic
│   ├── ChatViewModel+CalendarConfirmation.swift ← Confirm/cancel/undo
│   ├── ChatViewModel+MessageHandling.swift ← Send/stream/live-activity
│   ├── ChatViewModel+Speech.swift ← Voice recording + haptics
│   ├── ChatViewModel+Persistence.swift ← Save/load message history
│   ├── ChatViewModel+Publishers.swift  ← Combine subscriptions
│   ├── SessionListViewModel.swift ← Session CRUD + Siri routing
│   ├── SettingsViewModel.swift   ← Settings form logic
│   └── AppSettings.swift         ← @AppStorage preferences
└── Views/
    ├── ChatView.swift            ← Message list + toolbar
    ├── ChatView+Banners.swift    ← Template pill banners
    ├── ChatView+InputBar.swift   ← Pinned prompt chips + input
    ├── ChatView+Subviews.swift   ← Shared subview builders
    ├── ChatSessionContainer.swift← Session lifecycle wrapper
    ├── MessageBubbleView.swift   ← Per-message bubble + long-press
    ├── SessionListView.swift     ← Session browser
    ├── SessionListView+Subviews.swift ← Search bar + row subviews
    ├── CalendarEventCard.swift   ← Event preview card
    ├── ThinkingDisclosure.swift  ← Expandable thinking block
    ├── SettingsView.swift        ← Settings form
    └── HabitCelebrationOverlay.swift ← Canvas confetti celebration overlay
```
