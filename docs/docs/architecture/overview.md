---
sidebar_position: 1
---

# Architecture Overview

MVVM layers, dependency injection, and actor isolation in PocketMind.

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
├─────────────────────────────────────┤
│         Models / Domain Types       │  ← Pure data, no UIKit/SwiftUI
│  ChatMessage  ChatSession           │
│  CalendarEventPreview  ModelInfo    │
└─────────────────────────────────────┘
```

## Dependency Injection

PocketMind uses **constructor injection** throughout. All service dependencies are declared as protocol existentials (`any XProtocol`), never concrete types.

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

**`PocketMindApp`** is the sole composition root — the only place concrete services are instantiated:

```swift
@main struct PocketMindApp: App {
    private let llmService = LLMService()
    private let calendarService = CalendarService()
    private let hapticService = HapticService()
    // ...injected into SessionListViewModel
}
```

## Actor Isolation

| Actor | Purpose |
|-------|---------|
| `@MainActor` | All ViewModels and ObservableObjects — guarantees UI updates on main thread |
| `LlamaActor` | Serial actor wrapping llama.cpp C FFI — serializes inference, safe for async |

```swift
actor LlamaActor {
    // All calls serialized — no data races on C pointers
    func generate(prompt: String) async throws -> String { ... }
}
```

## Protocol Inventory

| Protocol | Conforming Type | Mock |
|----------|----------------|------|
| `LLMServiceProtocol` | `LLMService` | `MockLLMService` |
| `CalendarServiceProtocol` | `CalendarService` | `MockCalendarService` |
| `CalendarActionControllerProtocol` | `CalendarActionController` | `MockCalendarActionController` |
| `SessionManagerProtocol` | `SessionManager` | `MockSessionManager` |
| `SpeechServiceProtocol` | `SpeechService` | `MockSpeechService` |
| `HapticServiceProtocol` | `HapticService` | `MockHapticService` |
| `ChatHistoryManagerProtocol` | `ChatHistoryManager` / `NoOpChatHistoryManager` | — |
| `ModelDownloaderProtocol` | `ModelDownloader` | `MockModelDownloader` |
| `AppSettingsProtocol` | `AppSettings` | `MockAppSettings` |

## File Structure

```
Sources/
├── App/
│   ├── PocketMindApp.swift       ← @main, composition root
│   ├── ContentView.swift         ← Root navigation (onboarding → sessions)
│   └── AppDelegate.swift         ← UIApplicationDelegate (background tasks)
├── Models/
│   ├── ChatMessage.swift         ← Message struct, CalendarEventPreview
│   ├── ChatSession.swift         ← Session and SessionMeta types
│   ├── CalendarActionModels.swift← Payload and result types
│   └── ModelInfo.swift           ← GGUF model metadata
├── Services/
│   ├── LLMService.swift          ← Model load/unload, streaming
│   ├── LlamaActor.swift          ← llama.cpp serial actor
│   ├── CalendarService.swift     ← EventKit abstraction
│   ├── CalendarActionController.swift ← LLM JSON → calendar action
│   ├── CalendarFreeSlotEngine.swift   ← Pure slot-finding algorithm
│   ├── SessionManager.swift      ← Multi-session persistence
│   └── HapticService.swift       ← UIImpactFeedbackGenerator wrapper
├── ViewModels/
│   ├── ChatViewModel.swift       ← Core message/stream logic
│   ├── ChatViewModel+CalendarConfirmation.swift ← Confirm/cancel/undo
│   ├── ChatViewModel+SystemPrompt.swift ← Prompt construction + calendar dispatch
│   ├── SessionListViewModel.swift ← Session CRUD + Siri routing
│   └── AppSettings.swift         ← @AppStorage preferences
└── Views/
    ├── ChatView.swift            ← Message list + input bar
    ├── SessionListView.swift     ← Session browser
    ├── CalendarEventCard.swift   ← Event preview card
    └── ThinkingDisclosure.swift  ← Expandable thinking block
```
