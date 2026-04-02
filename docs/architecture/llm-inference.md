---
sidebar_position: 2
---

# LLM Inference

How LucidPal streams tokens from llama.cpp to the SwiftUI UI.

## Flow

```
User sends message
       ↓
ChatViewModel.sendMessage()
       ↓
Build system prompt (calendar context injected — see [System Prompt Builder](./system-prompt))
       ↓
llmService.generate() → AsyncThrowingStream<String>
       ↓
LlamaActor.generate() — serial actor, C FFI
       ↓
Token-by-token via AsyncThrowingStream
       ↓
applyStreamToken() — think/response split
       ↓
executeCalendarActions() — extract + execute JSON blocks
       ↓
Update messages array → SwiftUI re-renders
```

## Token Streaming

`LLMService.generate()` returns an `AsyncThrowingStream<String, Error>` — each element is one token (~1 word fragment). `ChatViewModel` consumes this stream and applies each token live:

```swift
for try await token in llmService.generate(
    systemPrompt: systemPrompt,
    messages: historyMessages,
    thinkingEnabled: showThinking
) {
    guard let idx = messages.firstIndex(where: { $0.id == assistantID }) else { break }
    applyStreamToken(token, rawBuffer: &raw, thinkDone: &thinkDone, ...)
}
```

### Token travel path (end-to-end)

```
llama.cpp C layer
  llama_sampler_sample()          ← samples next token ID from logits
  llama_token_to_piece()          ← converts token ID → raw [CChar] bytes
  decodeUTF8([CChar])             ← buffers incomplete UTF-8 sequences,
                                     flushes when valid string boundary found
  continuation.yield(str)         ← emits String into AsyncThrowingStream
        ↓
LLMService (actor bridge)
  for try await token in stream   ← re-yields each fragment upstream
        ↓
ChatViewModel.runGenerationLoop()
  applyStreamToken(token, ...)    ← routes token to think buffer or content
        ↓
@Published messages[idx].content  ← triggers SwiftUI diff
        ↓
MessageBubbleView / ThinkingDisclosure
  re-rendered on every token yield
```

`decodeUTF8` is the only buffering step before the stream: it holds `CChar` bytes in a pending buffer until `String(validatingUTF8:)` succeeds, ensuring multi-byte characters (e.g. emoji, CJK) are never split across yields.

## Stop Conditions

`streamTokens` (in `LlamaActor+Generate.swift`) exits the autoregressive loop on the first matching condition:

| Condition | Check | Behaviour |
|-----------|-------|-----------|
| EOS / EOG token | `llama_vocab_is_eog(vocab, newTok)` | Clean stop, stream finishes normally |
| `maxNewTokens` reached | `currentCursor - startCur >= maxNew` (default 768) | Clean stop |
| Context window full | `currentCursor >= ctxLimit` | Clean stop (last usable position) |
| Swift Task cancelled | `Task.isCancelled` checked each iteration | Breaks loop; partial content kept if non-empty |
| `llama_decode` failure | return value `!= 0` | Throws `LLMError.generateFailed` |
| Timeout | `withThrowingTaskGroup` race in `streamLLMResponse` | Throws `LLMError.timeout`; partial content shown + notice appended |

After any clean exit `flushPending(continuation:)` is called to emit any remaining buffered UTF-8 bytes before the stream is finished.

## Action Block Detection

Action blocks are **not parsed during streaming** — they are extracted after generation completes, in `finalizeResponse()`. The pipeline is:

```
Generation stream ends
        ↓
finalizeResponse(assistantID:)
        ↓
  extractWebSearchQuery()     → if [WEB_SEARCH:{...}] found, re-generate with results
        ↓
  executeCalendarActions()    → [CALENDAR_ACTION:{...}]  → EventKit
        ↓
  executeNoteActions()        → [NOTE_ACTION:{...}]      → NotesStore
        ↓
  executeContactsSearch()     → [CONTACTS_SEARCH:{...}]  → ContactsService
        ↓
  executeHabitActions()       → [HABIT_ACTION:{...}]     → HabitStore
        ↓
  executeReminderActions()    → [REMINDER_ACTION:{...}]  → EventKit reminders
        ↓
messages[idx].content stripped of action tokens
messages[idx].calendarEventPreviews / notePreviews / … populated
        ↓
SwiftUI renders action result cards (CalendarEventCard, NoteCard, …)
```

Each `execute*` call receives the full final `content` string, scans for its action tag using a regex or string search, decodes the embedded JSON payload, executes the side-effect, and returns a cleaned content string with the raw action token removed.

Web search is special: if a `[WEB_SEARCH:{...}]` block is found, the assistant message is cleared and a **second** full generation pass runs with the search results injected as a user message, subject to the same timeout.

## Thinking Mode (Qwen3.5 `<think>` Tags)

Qwen3.5 models emit a `<think>...</think>` block before answering. LucidPal handles this live:

```
<think>
The user wants to create an event...
</think>
Here's your event — tap confirm.
```

`applyStreamToken()` buffers the prefix and splits at `</think>`:

| Buffer state                         | Action                                              |
| ------------------------------------ | --------------------------------------------------- |
| Starts with `<think>` (no close yet) | Set `isThinking = true`, show in ThinkingDisclosure |
| `</think>` detected                  | Extract thinking text, reset to response mode       |
| No `<think>` prefix                  | Treat entire output as response                     |

`applyStreamToken` is called on every individual token during streaming. The `rawBuffer` accumulates the full output so far. Think-block detection happens **live** — `isThinking` and `thinkingContent` are updated on each token, so `ThinkingDisclosure` animates in real time while the model is still generating.

If the model emits text before any `<think>` tag (i.e. `rawBuffer` does not start with `<think>` and is not a prefix of it), `thinkDone` is set immediately and all subsequent tokens go directly to `messages[idx].content`.

## Tokenize Path

`LlamaActor+Tokenize.swift` exposes three low-level helpers used exclusively within `LlamaActor`:

| Function | Purpose | Called by |
|----------|---------|-----------|
| `tokenize(text:addBOS:parseSpecial:vocab:)` | Converts a prompt string → `[llama_token]` via `llama_tokenize` | `generate()` before prefill |
| `tokenToPiece(token:vocab:)` | Converts a sampled token ID → raw `[CChar]` bytes via `llama_token_to_piece` | `streamTokens()` each iteration |
| `decodeUTF8([CChar])` | Assembles valid UTF-8 strings from raw byte sequences, buffering incomplete multi-byte chars | `streamTokens()` after each `tokenToPiece` |

`tokenize` is called once per generation turn to produce the full prompt token array, which is then truncated to `contextSize - maxNewTokens` if needed and passed to `prefill`. It is **not** called for every token during generation — only during the initial prompt encoding step.

For vision (mtmd) input, tokenisation is handled separately by `mtmd_tokenize` which interleaves text tokens with image embedding chunks; the `tokenize` helper is bypassed for that path.

## Context Window

Context size is chosen based on device RAM at launch:

```swift
let ramGB = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
let historyLimit = ramGB >= 6
    ? ChatConstants.largeHistoryLimit   // 50 messages ≈ 5 000 tokens
    : ChatConstants.smallHistoryLimit   // 20 messages ≈ 2 000 tokens
```

| RAM    | Context   | History Limit |
| ------ | --------- | ------------- |
| < 6 GB | 4K tokens | 20 messages   |
| ≥ 6 GB | 8K tokens | 50 messages   |

## Sampler Configuration

| Parameter      | Value | Reason                                 |
| -------------- | ----- | -------------------------------------- |
| Temperature    | 0.35  | Low — reduces hallucinated JSON fields |
| Max new tokens | 768   | Prevents runaway generation            |

The sampler chain uses temperature + random distribution (`llama_sampler_init_dist`). No top-p/top-k sampler is applied.

## LlamaActor

`LlamaActor` is a Swift `actor` wrapping llama.cpp's C API. All calls are serialized on a single actor executor — no concurrent inference, no data races on C pointers.

### Dual-model architecture

LucidPal supports two model roles via the `ModelType` enum:

```swift
enum ModelType: Sendable {
    case text    // Qwen3.x text model
    case vision  // Qwen3-VL vision model (or integrated text+vision)
}
```

Each role has its own independent llama.cpp model/context/vocab/sampler pointers. A model can be loaded, unloaded, or swapped per role without affecting the other.

### Model loading & unloading lifecycle

```swift
// Load a text model
try await actor.loadModel(at: path, contextSize: 8192, role: .text)

// Load a vision model — on low-RAM devices (<6 GB), the text model is
// automatically unloaded first to free memory
try await actor.loadModel(at: path, contextSize: 4096, role: .vision,
                          mmprojPath: mmprojPath)

// Unload a specific role
actor.unloadModel(role: .text)

// Unload all models
actor.unload()
```

On low-RAM devices (< 6 GB), loading a vision model when a text model is already active triggers an automatic `unloadModel(role: .text)` before loading.

### Metal warm-up

After every model load, `warmup(role:)` decodes a single BOS token to pre-initialize Metal pipeline state, avoiding a cold-start latency spike on the first real generation.

### Text-only generation

`generate(prompt:role:continuation:)` runs the full prefill → autoregressive decode loop:

1. Tokenize prompt via `llama_tokenize`
2. Truncate to `contextSize - maxNewTokens` if needed (keeps most-recent content)
3. Prefill: batch all prompt tokens → `llama_decode`
4. Stream: sample one token per step via `llama_sampler_sample`, yield via `continuation.yield`
5. Stop on EOS/EOG token, cancellation, or `maxNewTokens` (768) limit

### Vision generation (mtmd / CLIP)

`generateWithImages(prompt:imageDataList:role:continuation:)` handles multimodal input:

1. Decode raw JPEG buffers into `mtmd` bitmaps (`mtmd_helper_bitmap_init_from_buf`)
2. Tokenize prompt + bitmaps together via `mtmd_tokenize` into input chunks
3. Evaluate chunks (text + image embeddings) via `mtmd_helper_eval_chunks`
4. Stream output tokens with the same `streamTokens` loop as text-only

If `mtmdCtx` is not available (no mmproj loaded), falls back to text-only generation automatically.

### Integrated vision model

When a text model also handles vision (e.g. Qwen3-VL integrated), `textModelSupportsVision = true`. In this case `generate(role: .vision)` transparently uses the text model slot — no separate vision slot needed.

:::warning
`LlamaActor` requires a physical device — the llama.cpp Metal backend does not run in the Simulator. GPU layers are set to 0 in `#if targetEnvironment(simulator)`.
:::

## Error Handling

| Error                     | Source                                     | Handling                                     |
| ------------------------- | ------------------------------------------ | -------------------------------------------- |
| `LLMError.modelNotLoaded` | `LLMService.generate` when model not ready | ChatViewModel shows error banner             |
| `CancellationError`       | User taps stop button                      | Partial content left visible, no error shown |
| Any other `Error`         | llama.cpp runtime                          | Displayed in `messages[idx].content`         |
