---
sidebar_position: 10
---

# Testing Guide

## Running the Test Suite

```bash
xcodebuild test \
  -project apps/lucidpal-ios/LucidPal.xcodeproj \
  -scheme LucidPal \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

All tests run on the iOS Simulator — no physical device required.

## Test File Inventory

| File | What it Covers |
|------|----------------|
| `CalendarActionControllerTests.swift` | JSON → calendar action dispatch (create, update, delete) |
| `CalendarActionControllerHelpersTests.swift` | Helper functions used by the controller |
| `CalendarActionModelsDecodingTests.swift` | Codable decoding of calendar action payloads |
| `CalendarCancellationTests.swift` | Event cancellation flows |
| `CalendarConfirmationTests.swift` | User confirmation prompts before mutations |
| `CalendarDomainTypesTests.swift` | Value-type invariants on domain models |
| `CalendarFreeSlotEngineTests.swift` | Free-slot algorithm (unit) |
| `CalendarFreeSlotIntegrationTests.swift` | Free-slot algorithm (integration with mock calendar) |
| `CalendarServiceTests.swift` | `CalendarService` CRUD against mock EventKit |
| `CalendarViewSmokeTests.swift` | Calendar view renders without crash |
| `ConflictResolutionTests.swift` | Overlapping event conflict logic |
| `PendingCalendarUpdateTests.swift` | Pending-update state transitions |
| `ChatViewModelTests.swift` | Deletion/confirmation actions on `ChatViewModel` |
| `ChatViewModelEdgeCaseTests.swift` | Edge cases (empty input, nil state, rapid sends) |
| `ChatViewModelMessageHandlingTests.swift` | Message append and role assignment |
| `ChatViewModelPersistenceTests.swift` | Session persistence via `MockChatHistoryManager` |
| `ChatViewModelSendMessageTests.swift` | Send flow with mocked LLM |
| `ChatViewModelSpeechTests.swift` | Speech trigger and stop integration |
| `ChatViewModelStreamTests.swift` | Streaming token accumulation |
| `ChatViewModelSuggestedPromptsTests.swift` | Suggested prompts display logic |
| `ChatViewModelSystemPromptTests.swift` | System prompt injection |
| `ChatViewModelWebSearchTests.swift` | Web search result injection into chat |
| `LlamaActorTests.swift` | Observable state + `LLMConstants` sanity checks (no model load) |
| `LLMConstantsTests.swift` | Numeric constant invariants |
| `LLMServiceProtocolTests.swift` | Protocol conformance contract |
| `VisionImageProcessorTests.swift` | Image resize/aspect ratio/base64 encoding |
| `SessionManagerTests.swift` | Session CRUD and lifecycle |
| `SessionManagerMigrationTests.swift` | Legacy data migration |
| `SessionListViewModelTests.swift` | Session list state management |
| `SessionListViewModelCalendarTests.swift` | Calendar integration in session list |
| `SpeechServiceTests.swift` | `SpeechService` start/stop/error states |
| `WhisperSpeechServiceTests.swift` | Whisper transcription path |
| `AirPodsVoiceCoordinatorTests.swift` | AirPods audio route detection |
| `AudioRouteMonitorTests.swift` | Audio route change notifications |
| `SystemPromptBuilderTests.swift` | System prompt assembly |
| `ContextServiceTests.swift` | Context injection into prompts |
| `SuggestedPromptsProviderTests.swift` | Prompt suggestion generation |
| `WebSearchServiceTests.swift` | Web search service request/response |
| `ModelDownloaderTests.swift` | GGUF model download state machine |
| `ModelDownloadViewModelTests.swift` | Download progress UI state |
| `ModelInfoTests.swift` | Model metadata parsing |
| `HabitStoreTests.swift` | Habit CRUD and streak logic |
| `NotesStoreTests.swift` | Notes persistence |
| `ChatHistoryManagerTests.swift` | Chat history read/write |
| `ChatMessageTests.swift` | `ChatMessage` value semantics |
| `AppSettingsTests.swift` | Settings read/write and defaults |
| `SettingsViewModelTests.swift` | Settings view state |
| `OnboardingTests.swift` | Onboarding step sequencing |
| `DebugLogStoreTests.swift` | Debug log capture |
| `DesignConstantsTests.swift` | UI constant invariants |
| `UserDefaultsKeysTests.swift` | Key uniqueness and type safety |
| `HapticServiceProtocolTests.swift` | Haptic protocol contract |
| `SiriCalendarBridgeTests.swift` | Siri → calendar bridge |
| `SiriContextStoreTests.swift` | Siri context persistence |
| `SiriIntentTests.swift` | Intent handling |
| `SiriPendingEventTests.swift` | Pending event from Siri |
| `ShortcutIntentTests.swift` | App shortcut intents |
| `ViewSmokeTests.swift` | Key views render without crash |
| `CalendarViewSmokeTests.swift` | Calendar view renders without crash |
| `SnapshotTests.swift` | Visual regression snapshots |

## Mock Inventory

All mocks live in `Tests/` and conform to the corresponding protocol:

| Mock | Protocol | Used By |
|------|----------|---------|
| `MockLLMService.swift` | `LLMServiceProtocol` | All `ChatViewModel` tests |
| `MockCalendarService.swift` | `CalendarServiceProtocol` | Calendar + ChatViewModel tests |
| `MockCalendarActionController.swift` | `CalendarActionControllerProtocol` | ChatViewModel tests |
| `MockChatHistoryManager.swift` | `ChatHistoryManagerProtocol` | Persistence tests |
| `MockContextService.swift` | `ContextServiceProtocol` | Prompt-building tests |
| `MockHapticService.swift` | `HapticServiceProtocol` | ViewModel tests |
| `MockLocationService.swift` | `LocationServiceProtocol` | Context/system-prompt tests |
| `MockModelDownloader.swift` | `ModelDownloaderProtocol` | Download flow tests |
| `MockSessionManager.swift` | `SessionManagerProtocol` | Session tests |
| `MockSpeechService.swift` | `SpeechServiceProtocol` | Speech/AirPods tests |
| `MockSuggestedPromptsProvider.swift` | `SuggestedPromptsProviderProtocol` | ChatViewModel tests |
| `MockSystemPromptBuilder.swift` | `SystemPromptBuilderProtocol` | ChatViewModel tests |
| `MockWebSearchService.swift` | `WebSearchServiceProtocol` | Web search tests |
| `MockAppSettings.swift` | `AppSettingsProtocol` | Settings + controller tests |

## Testing Patterns

### ViewModel tests

`ChatViewModel` and `SessionListViewModel` are instantiated with a `*Dependencies` struct that accepts protocol types. Tests inject mocks at construction time:

```swift
viewModel = ChatViewModel(
    dependencies: ChatViewModelDependencies(
        llmService: MockLLMService(),
        calendarService: MockCalendarService(),
        settings: MockAppSettings(),
        // ...
    )
)
```

All test classes are annotated `@MainActor` to match the production actor isolation. `setUp` uses `async throws`.

### Service-layer tests

Controllers (e.g., `CalendarActionController`) accept their dependencies through initializer injection. Tests pass mock services and assert on the mock's recorded calls (e.g., `mock.createdEvents.count`).

### Value-type / constants tests

Files like `LLMConstantsTests`, `DesignConstantsTests`, and `UserDefaultsKeysTests` assert numeric bounds and key uniqueness directly — no mocks needed.

### Image processing tests

`VisionImageProcessorTests` creates synthetic `UIImage` instances via a `makeTestImage(size:)` helper and exercises the processor's public API without network or file I/O.

### Smoke / snapshot tests

`ViewSmokeTests` and `SnapshotTests` instantiate SwiftUI views and verify they render without crashing. Snapshot tests capture reference images stored alongside the test target.

## What is NOT Tested

| Area | Reason |
|------|--------|
| `LlamaActor` generate / load | Requires a GGUF model file and ARM64 device; CI runs on Simulator |
| Real `EKEventStore` mutations | EventKit requires user permission grant; tests use `MockCalendarService` |
| Real `CLGeocoder` | Network-dependent; replaced by `MockLocationService` |
| Full UI interaction tests | No XCUITest suite exists yet |
| On-device Whisper transcription | Hardware-dependent; `WhisperSpeechService` is mocked above the C layer |

`LlamaActorTests` deliberately covers only observable state (`isLoaded`) and `LLMConstants` so CI can pass without hardware.

## Adding a New Test File

1. Create `Tests/MyFeatureTests.swift` inside the `lucidpal-ios` Xcode project (target: **LucidPalTests**).
2. Import and mark the actor:

```swift
import XCTest
@testable import LucidPal

@MainActor
final class MyFeatureTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        // inject mocks
    }

    func testSomething() async throws {
        // arrange → act → assert
    }
}
```

3. If your feature has external dependencies (network, EventKit, CoreLocation), add a corresponding `Mock*.swift` file conforming to the relevant protocol.
4. Run the suite locally with the `xcodebuild test` command above before opening a PR.
