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
