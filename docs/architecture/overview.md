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
│  SystemPromptBuilder  NotesStore    │
│  NoteEnrichmentService  ContextService│
│  SuggestedPromptsProvider           │
│  WebSearchService                   │
├─────────────────────────────────────┤
│         Models / Domain Types       │  ← Pure data, no UIKit/SwiftUI
│  ChatMessage  ChatSession           │
│  CalendarEventPreview  ModelInfo    │
└─────────────────────────────────────┘
```

For how the Services layer assembles the AI system prompt, see [System Prompt Builder](./system-prompt).

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

See [LLM Inference](./llm-inference) for full `LlamaActor` internals, model loading, and streaming token generation.

## Protocol Inventory

| Protocol                           | Conforming Type                                 | Mock                           |
| ---------------------------------- | ----------------------------------------------- | ------------------------------ |
| `LLMServiceProtocol`               | `LLMService`                                    | `MockLLMService`               |
| `CalendarServiceProtocol`          | `CalendarService`                               | `MockCalendarService`          |
| `DocumentProcessorProtocol`        | `DocumentProcessor`                             | —                              |
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
| `ContextServiceProtocol`           | `ContextService`                                | —                              |
| `SuggestedPromptsProviderProtocol` | `SuggestedPromptsProvider`                      | —                              |

> **Note:** `NoteEnrichmentService` is a concrete service (no protocol) — it is injected directly into `NotesListViewModel` for async LLM-driven note enrichment.

**Deep-dive pages for key protocols:**

- `SessionManagerProtocol` → [Sessions](./sessions)
- `HabitStoreProtocol` → [Habit Store](./habit-store)
- `NotesStoreProtocol` → [Notes Store](./notes-store)
- `NoteEnrichmentService` → [Note Enrichment](./note-enrichment)
- `ContextServiceProtocol` / `SuggestedPromptsProviderProtocol` → [Chat ViewModel](./chat-viewmodel)

## Model Download Pipeline

The download pipeline involves two services working in sequence:

| Service | Role |
| ------- | ---- |
| `ModelDownloader` | Downloads the GGUF file via an iOS background `URLSession`. Uses resume data to avoid restarting interrupted transfers. Verifies the file with a SHA-256 checksum after each download. |
| `ModelPageCacheWarmer` | After a successful download, prefetches model pages into RAM using `mlock`-style reads. This reduces the cold-start latency the first time `LLMService` loads the model. |

`ModelDownloader` uses session identifier `app.lucidpal.model-download`, which lets iOS reconnect to an in-progress transfer across app launches. `AppDelegate` stores the system's completion handler in `ModelDownloader.backgroundSessionCompletion` so the OS is notified once all background events are processed.

For the full download state machine, background session handling, and cache warming details, see [Model Download](./model-download).

## Testing and CI/CD

- Unit and integration test patterns → [Testing](./testing)
- Fastlane lanes, GitHub Actions workflows → [CI/CD](./ci-cd)

## File Structure

```
Sources/
├── App/
│   ├── LucidPalApp.swift       ← @main, composition root
│   ├── ContentView.swift         ← Root navigation (onboarding → sessions)
│   └── AppDelegate.swift         ← UIApplicationDelegate (background tasks)
├── Models/
│   ├── CalendarActionModels.swift← Payload and result types
│   ├── ChatMessage.swift         ← Message struct, CalendarEventPreview
│   ├── ChatSession.swift         ← Session and SessionMeta types
│   ├── ContextItem.swift         ← Attached context items (documents, images)
│   ├── ConversationTemplate.swift← Template definitions for system prompts
│   ├── HabitModels.swift         ← Habit and habit-log domain types
│   ├── LucidPalActivityAttributes.swift ← Live Activity attributes
│   ├── ModelInfo.swift           ← GGUF model metadata
│   ├── NoteItem.swift            ← Note model with AI metadata fields
│   ├── PinnedPrompt.swift        ← Pinned prompt data model
│   └── ReminderPreview.swift     ← Reminder preview for display
├── Services/
│   ├── AirPodsVoiceCoordinator.swift  ← AirPods mic routing coordinator
│   ├── AudioRouteMonitor.swift        ← AVAudioSession route-change observer
│   ├── CalendarActionController.swift ← LLM JSON → calendar action
│   ├── CalendarActionController+Helpers.swift ← Action controller utilities
│   ├── CalendarError.swift            ← Calendar error types
│   ├── CalendarFreeSlotEngine.swift   ← Pure slot-finding algorithm
│   ├── CalendarPromptSection.swift    ← Calendar section of system prompt
│   ├── CalendarService.swift          ← EventKit abstraction
│   ├── CalendarServiceProtocol.swift  ← Protocol for calendar access
│   ├── ChatHistoryManager.swift       ← Message history persistence
│   ├── ContactsActionController.swift ← LLM JSON → contacts action
│   ├── ContactsPromptSection.swift    ← Contacts section of system prompt
│   ├── ContactsService.swift          ← Contacts framework abstraction
│   ├── ContactsServiceProtocol.swift  ← Protocol for contacts access
│   ├── ContextService.swift           ← Attached context item management
│   ├── ContextServiceProtocol.swift   ← Protocol for context service
│   ├── DebugLogStore.swift            ← In-memory debug log storage
│   ├── DocumentProcessor.swift        ← PDF/document text extraction
│   ├── DocumentProcessorProtocol.swift← Protocol for document processing
│   ├── HabitActionController.swift    ← LLM JSON → habit action
│   ├── HabitPromptSection.swift       ← Habit section of system prompt
│   ├── HabitStore.swift               ← Habit log persistence (ObservableObject)
│   ├── HabitStoreProtocol.swift       ← Protocol for habit store
│   ├── HapticService.swift            ← UIImpactFeedbackGenerator wrapper
│   ├── LiveActivityService.swift      ← Live Activity start/update/end
│   ├── LlamaActor.swift               ← llama.cpp serial actor (base)
│   ├── LlamaActor+Generate.swift      ← Token generation extension
│   ├── LlamaActor+Tokenize.swift      ← Tokenization extension
│   ├── LLMService.swift               ← Model load/unload, streaming
│   ├── LLMServiceProtocol.swift       ← Protocol for LLM service
│   ├── LocationService.swift          ← CoreLocation geocoding wrapper
│   ├── ModelDownloader.swift          ← GGUF download + checksum verification
│   ├── ModelPageCacheWarmer.swift     ← Prefetch model pages into RAM
│   ├── NoteActionController.swift     ← LLM JSON → note action
│   ├── NoteEnrichmentService.swift    ← Async LLM enrichment for notes
│   ├── NotesPromptSection.swift       ← Notes section of system prompt
│   ├── NotesStore.swift               ← Notes persistence (ObservableObject)
│   ├── NotesStoreProtocol.swift       ← Protocol for notes store
│   ├── NotificationService.swift      ← UNUserNotificationCenter wrapper
│   ├── PinnedPromptsStore.swift       ← Pinned prompts persistence
│   ├── PromptSection.swift            ← Base protocol for prompt sections
│   ├── ReminderActionController.swift ← LLM JSON → reminder action
│   ├── ReminderPromptSection.swift    ← Reminder section of system prompt
│   ├── SessionManager.swift           ← Multi-session persistence
│   ├── SpeechService.swift            ← AVFoundation speech recognition
│   ├── SpeechServiceProtocol.swift    ← Protocol for speech service
│   ├── SuggestedPromptsProvider.swift ← Context-aware prompt suggestions
│   ├── SystemPromptBuilder.swift      ← Assembles full system prompt
│   ├── VisionImageProcessor.swift     ← Image resize + base64 for vision models
│   ├── WebSearchService.swift         ← Web search integration
│   └── WhisperSpeechService.swift     ← On-device Whisper transcription
├── ViewModels/
│   ├── AppSettings.swift              ← @AppStorage preferences
│   ├── AppSettingsProtocol.swift      ← Protocol for app settings
│   ├── ChatConstants.swift            ← Shared chat constants (token limits etc.)
│   ├── ChatViewModel.swift            ← Core message/stream logic
│   ├── ChatViewModel+CalendarConfirmation.swift ← Confirm/cancel/undo
│   ├── ChatViewModel+MessageHandling.swift ← Send/stream/live-activity
│   ├── ChatViewModel+Persistence.swift ← Save/load message history
│   ├── ChatViewModel+Publishers.swift  ← Combine subscriptions
│   ├── ChatViewModel+Speech.swift     ← Voice recording + haptics
│   ├── ChatViewModelDependencies.swift ← Dependency container for ChatViewModel
│   ├── ModelDownloadViewModel.swift   ← Model download progress and state
│   ├── SessionListViewModel.swift     ← Session CRUD + Siri routing
│   ├── SessionListViewModelDependencies.swift ← Dependency container for SessionListViewModel
│   ├── SettingsViewModel.swift        ← Settings form logic
│   └── UserDefaultsKeys.swift        ← UserDefaults key constants
└── Views/
    ├── BulkDeletionBar.swift          ← Multi-select delete toolbar
    ├── CalendarActionPill.swift       ← Inline calendar action confirmation
    ├── CalendarEventCard.swift        ← Event preview card
    ├── CalendarEventCard+Pending.swift← Pending-confirmation card state
    ├── CalendarEventCard+Subviews.swift← Event card subview builders
    ├── CalendarEventListCard.swift    ← List of calendar events card
    ├── CalendarQueryResultCard.swift  ← Calendar query result display
    ├── ChatInputBar.swift             ← Text input bar component
    ├── ChatSessionContainer.swift     ← Session lifecycle wrapper
    ├── ChatView.swift                 ← Message list + toolbar
    ├── ChatView+Banners.swift         ← Template pill banners
    ├── ChatView+InputBar.swift        ← Pinned prompt chips + input
    ├── ChatView+Subviews.swift        ← Shared subview builders
    ├── ConflictDetailSheet.swift      ← Scheduling conflict detail sheet
    ├── ContactResultCard.swift        ← Contact lookup result card
    ├── CreateEventSheet.swift         ← Manual event creation form
    ├── DebugLogView.swift             ← In-app debug log viewer
    ├── DesignConstants.swift          ← Shared design tokens
    ├── DocumentAttachmentPill.swift   ← Document attachment chip
    ├── DocumentPickerButton.swift     ← Document picker trigger button
    ├── HabitCard.swift                ← Habit summary card
    ├── HabitCreationSheet.swift       ← New habit creation form
    ├── HabitDashboardView.swift       ← Habit overview dashboard
    ├── HabitDetailView.swift          ← Single habit detail and log
    ├── HabitLogSheet.swift            ← Log a habit entry sheet
    ├── MessageBubbleView.swift        ← Per-message bubble + long-press
    ├── MessageBubbleView+ImageViewer.swift ← Full-screen image viewer
    ├── ModelDownloadView.swift        ← Model download progress screen
    ├── NoteCard.swift                 ← Note summary card
    ├── NoteEditorView.swift           ← Note editing view
    ├── NotesListView.swift            ← Notes list browser
    ├── OnboardingCarouselView.swift   ← First-launch onboarding carousel
    ├── ReminderCard.swift             ← Reminder result card
    ├── SessionListView.swift          ← Session browser
    ├── SessionListView+Subviews.swift ← Search bar + row subviews
    ├── SettingsView.swift             ← Settings form
    ├── SettingsView+Shortcuts.swift   ← Siri shortcuts settings section
    ├── SettingsView+VisionSection.swift← Vision model settings section
    ├── SiriEventCard.swift            ← Siri-triggered event card
    ├── SuggestedPromptsView.swift     ← Contextual prompt suggestions UI
    ├── ThinkingDisclosure.swift       ← Expandable thinking block
    ├── ToastView.swift                ← Ephemeral toast notification
    ├── UnsupportedDeviceView.swift    ← Low-RAM unsupported device screen
    ├── View+PremiumShadow.swift       ← Premium shadow view modifier
    ├── VoiceRecordingOverlay.swift    ← Voice recording in-progress overlay
    └── WebSearchSettingsView.swift    ← Web search settings section
```
