---
sidebar_position: 8
---

# ChatViewModel

The central view model for LucidPal's conversation engine. `ChatViewModel` owns the full message lifecycle — from user input through LLM streaming to action parsing and persistence.

## Role and Responsibility

`ChatViewModel` is a `@MainActor final class` that conforms to `ObservableObject`. It owns everything visible in the chat screen and coordinates all background work via Swift structured concurrency.

| Owned by ChatViewModel | Delegated to service |
|------------------------|----------------------|
| `messages: [ChatMessage]` state | LLM inference (`LLMServiceProtocol`) |
| Input text, image/doc attachments | Speech recognition (`SpeechServiceProtocol`) |
| Generation / loading / speech UI flags | Calendar CRUD (`CalendarServiceProtocol`) |
| Session title and reply-to state | History persistence (`ChatHistoryManagerProtocol`) |
| Pinned prompts list | Prompt building (`SystemPromptBuilderProtocol`) |
| In-chat search / filter | Haptic feedback (`HapticServiceProtocol`) |
| Error banner + auto-dismiss | Live Activity (`LiveActivityServiceProtocol`) |

## Extension File Breakdown

The class is split across seven files to keep each under ~300 lines:

| File | Responsibility |
|------|----------------|
| `ChatViewModel.swift` | Core state (`@Published` properties), init, image/doc/pinned-prompt helpers |
| `ChatViewModelDependencies.swift` | Value-type dependency bundle passed to init |
| `ChatViewModel+MessageHandling.swift` | `sendMessage()`, streaming, web search, `finalizeResponse()` |
| `ChatViewModel+CalendarConfirmation.swift` | User confirmation/cancellation of calendar actions in message cards |
| `ChatViewModel+Speech.swift` | `toggleSpeech()`, `confirmSpeech()`, `cancelSpeech()` |
| `ChatViewModel+Publishers.swift` | `setupPublishers()` — all Combine subscriptions |
| `ChatViewModel+Persistence.swift` | `sanitizeStaleState()`, `clearHistory()`, `flushPersistence()` |

## Key `@Published` Properties

| Property | Drives |
|----------|--------|
| `messages` | Chat bubble list, date separators, search filter |
| `isGenerating` | Send button → stop button swap, streaming indicator |
| `isPreparing` | `GeneratingStatusView` shown during system-prompt build |
| `isModelLoaded` / `isModelLoading` | Input bar enabled state, loading overlay |
| `inputText` | Input field text (bidirectional, also written by speech) |
| `isSpeechRecording` / `isSpeechTranscribing` | Mic button animation states |
| `isAutoListening` | AirPods auto-listen indicator |
| `thinkingEnabled` | Whether `<think>` blocks are parsed and shown |
| `replyingTo` | Quote strip above the input bar |
| `errorMessage` | Error banner (auto-dismissed after `ChatConstants.errorAutoDismissSeconds`) |
| `toast` | Transient toast notifications |
| `suggestedPrompts` | Prompt chip row shown on empty state |
| `sessionTitle` | Navigation bar title |
| `pinnedPrompts` | Pinned prompt chips above input bar |

## Send-Message Flow

```
User taps Send
      │
      ▼
sendMessage() — guard: not empty, not generating, model loaded
      │
      ├─ needsVision? → prepareVisionModel() (download mmproj if missing, load model)
      │
      ├─ Append ChatMessage(role: .user) to messages[]
      ├─ Auto-title session from first user message
      ├─ Snapshot historyMessages (suffix by RAM-based limit)
      ├─ Append ChatMessage(role: .assistant, content: "") — placeholder visible immediately
      │
      ├─ await systemPromptBuilder.buildSystemPrompt()
      │   └─ Prepend extracted document text if doc attachments present
      │
      ▼
streamLLMResponse()
      │  withThrowingTaskGroup — race generation vs. timeout task
      │
      ├─ runGenerationLoop()
      │   └─ for try await token in llmService.generate(...)
      │       └─ applyStreamToken() — strips <think>...</think>, updates messages[idx] in-place
      │
      └─ first task to finish wins; other is cancelled
            │
            ├─ LLMError.timeout → append "*(Response timed out)*"
            ├─ CancellationError → remove empty placeholder
            └─ other Error → set messages[idx].content = "Error: ..."
      │
      ▼
finalizeResponse()
      │
      ├─ Web search: extract [WEB_SEARCH:{...}] → fetch results → synthesis pass
      ├─ Calendar: executeCalendarActions() → attach CalendarEventPreview[] to message
      ├─ Notes: executeNoteActions() → attach NotePreviews[]
      ├─ Contacts: executeContactsSearch() → attach ContactResults[]
      ├─ Habits: executeHabitActions() → attach HabitPreviews[]
      └─ Reminders: executeReminderActions() → attach ReminderPreviews[]
```

### Think-Block Parsing

`applyStreamToken()` handles Qwen3's `<think>…</think>` prefix inline during streaming:

```swift
func applyStreamToken(
    _ token: String,
    rawBuffer: inout String,
    thinkDone: inout Bool,
    showThinking: Bool,
    idx: Int
)
```

- While inside `<think>`: sets `messages[idx].isThinking = true`, writes to `thinkingContent` if `thinkingEnabled`
- Once `</think>` is found: strips block, sets `thinkDone = true`, routes remaining tokens to `content`
- If no `<think>` prefix: sets `thinkDone = true` immediately on first token

## Calendar Confirmation Lifecycle

Calendar event previews embedded in assistant messages go through a state machine:

```
AI creates event → preview.state = .created / .pendingDeletion / .pendingUpdate
        │
        ▼
User sees confirmation card in ChatBubble
        │
   ┌────┴─────────────────────────────────┐
   │                                      │
confirmDeletion()              cancelDeletion()
   │                                      │
   ▼                                      ▼
state = .deleted               state = .deletionCancelled
   │
undoDeletion() → re-creates event via CalendarService
   │
   ▼
state = .restored

── Update path ──────────────────────────────────────
confirmUpdate()
   └─ calendarService.applyUpdate(pendingUpdate, to: identifier)
   └─ Mirror changed fields onto preview
   └─ pendingUpdate = nil
   └─ state = .updated / .rescheduled
        (CalendarError.eventNotFound → state = .updateCancelled, pendingUpdate = nil)

cancelUpdate()
   └─ state = .updateCancelled
   └─ pendingUpdate = nil

── Conflict path ─────────────────────────────────────
hasConflict = true → conflict card shown
   ├─ keepConflict()        → clears conflict indicators
   ├─ cancelConflict()      → deletes event, state = .deleted
   └─ rescheduleConflict()  → applyUpdate to free slot, state = .rescheduled
```

`findFreeSlotsForConflict()` searches a 7-day window using `CalendarFreeSlotEngine`, merging busy windows and returning gaps matching the event's duration (capped at 4 h; 2 h for all-day events).

## Speech Integration

```
User taps mic button
      │
      ▼
toggleSpeech()
      │
      ├─ isRecording = false → startRecording() + hapticService.voiceStarted()
      └─ isRecording = true  → confirmSpeech()
                                    └─ stopRecording() + hapticService.voiceDone()

cancelSpeech()
      └─ suppressSpeechAutoSend = true
         discardNextTranscript = true
         stopRecording() + hapticService.voiceCancelled()
```

Live transcript updates flow through `speechService.transcriptPublisher`:

```
speechService emits partial transcript
      │
      ▼  (Publisher in setupPublishers)
inputText = transcript   ← unless discardNextTranscript
```

Auto-send on silence:

```
speechService.isRecordingPublisher emits false
      │
      ├─ discardNextTranscript? → clear inputText, skip send
      ├─ suppressSpeechAutoSend? → skip send
      └─ settings.speechAutoSendEnabled + inputText non-empty → sendMessage()
```

`suppressSpeechAutoSend` is set only when the user manually taps the mic to stop (preserving auto-send for the natural silence-timeout path). `voiceAutoStartActive` tracks AirPods-triggered auto-start sessions.

## Combine Publisher Subscriptions

All subscriptions are set up in `setupPublishers()`, called once from `init`:

| Publisher | Action |
|-----------|--------|
| `llmService.isLoadingPublisher` | `isModelLoading = $0` |
| `llmService.isLoadedPublisher` | `isModelLoaded = $0`; kick off `generateSuggestedPrompts()` if empty |
| `llmService.isGeneratingPublisher` | `isGenerating = $0` |
| `llmService.contextTruncatedPublisher` | Show "conversation trimmed" toast |
| `speechService.isRecordingPublisher` | `isSpeechRecording = $0`; auto-send on `false` |
| `speechService.isAuthorizedPublisher` | `isSpeechAvailable = $0` |
| `speechService.isTranscribingPublisher` | `isSpeechTranscribing = $0` |
| `speechService.transcriptPublisher` | `inputText = transcript` (filtered when discarding) |
| `speechService.transcriptionErrorPublisher` | `errorMessage = $0` |
| `airPodsCoordinator?.isAutoListeningPublisher` | `isAutoListening = $0` |
| `$errorMessage` | Auto-dismiss after `ChatConstants.errorAutoDismissSeconds` |
| `$messages` (debounced) | Persist to session or history manager |

## Persistence

### On change (debounced)

```swift
$messages
    .debounce(for: .seconds(ChatConstants.persistenceDebounceSeconds), scheduler: RunLoop.main)
    .sink { msgs in
        if sessionManager != nil {
            sm.save(ChatSession(..., messages: msgs))   // → sessions/<uuid>.json
            onSessionUpdated?(session.meta)
        } else {
            history.save(msgs)                         // → chat_history.json (legacy)
        }
    }
```

### On app background

`flushPersistence()` writes synchronously (no debounce) — called by the app delegate when entering background.

### On launch

`init` loads from `session?.messages ?? historyManager.load()`, then calls `sanitizeStaleState()`:

```swift
static func sanitizeStaleState(_ messages: inout [ChatMessage]) {
    // Clear stuck isThinking flags
    // Replace interrupted [WEB_SEARCH:] content with "*(Search was interrupted.)*"
    // Strip raw [CALENDAR_ACTION:] blocks never executed
    // Remove empty assistant placeholders (killed before any token arrived)
}
```

Session mode replaces `historyManager` with `NoOpChatHistoryManager` so `chat_history.json` is never written.

## ChatViewModelDependencies Pattern

`ChatViewModelDependencies` is a plain `struct` that bundles all service protocols:

```swift
struct ChatViewModelDependencies {
    let llmService: any LLMServiceProtocol
    let calendarService: any CalendarServiceProtocol
    let settings: any AppSettingsProtocol
    let systemPromptBuilder: any SystemPromptBuilderProtocol
    let suggestedPromptsProvider: any SuggestedPromptsProviderProtocol
    let speechService: any SpeechServiceProtocol
    let hapticService: any HapticServiceProtocol
    let historyManager: any ChatHistoryManagerProtocol
    // Optional services — default nil
    let airPodsCoordinator: (any AirPodsVoiceCoordinatorProtocol)?
    let webSearchService: (any WebSearchServiceProtocol)?
    let pinnedPromptsStore: (any PinnedPromptsStoreProtocol)?
    let liveActivityService: (any LiveActivityServiceProtocol)?
    let documentProcessor: (any DocumentProcessorProtocol)?
}
```

**Why a bundle struct?** The `ChatViewModel` init would otherwise take 13+ parameters. The struct reduces the call site to 5 parameters (`dependencies`, `session`, `sessionManager`, `onSessionUpdated`, `pendingInput`) and makes optional services explicit at the struct level with default `nil` values.

All required services are non-optional; optional services (AirPods, web search, live activity, document processing) default to `nil` so `ChatViewModel` gracefully degrades when a feature is unavailable or disabled.
