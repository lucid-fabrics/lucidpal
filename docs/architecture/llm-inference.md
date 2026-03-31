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
Build system prompt (calendar context injected)
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

## Dual-Model Architecture (Vision)

LucidPal supports a dual-model setup where a text model and a vision model can coexist. When the user selects the **Qwen3.5 Vision 4B** integrated model, it acts as both:

- A text inference model for all conversational turns
- A vision model that encodes images via a CLIP multimodal projector (`mmproj`)

```
User attaches image
       ↓
VisionImageProcessor → resize to 896×896, JPEG 0.8, base64
       ↓
LLMService builds vision prompt (ChatML with <__media__> markers)
       ↓
LlamaActor.loadModel(role: .text, isIntegrated: true, mmprojPath: ...)
       ↓
mtmd_encode_image() — image encoded via CLIP projector (Metal)
       ↓
Token generation proceeds with visual context injected
```

On low-RAM devices (< 6 GB), loading a vision model while a text model is active automatically unloads the text model first.

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

Context size is chosen based on device RAM at launch. The four tiers map to Apple's marketing RAM sizes (which report as smaller binary GB values):

| Binary RAM | Marketing RAM | Context    | Model tier | History limit |
| ---------- | ------------- | ---------- | ---------- | ------------- |
| < 3 GB     | 4 GB (iPhone 12, 13, SE) | 4,096 tokens | 0.8B | 20 messages |
| 3–5 GB     | 4–6 GB (iPhone 13 non-Pro, 12) | 8,192 tokens | 2B | 20 messages |
| 5–7 GB     | 6 GB (iPhone 13 Pro, 14, 15) | 16,384 tokens | 4B | 50 messages |
| ≥ 7 GB     | 8 GB (iPhone 15 Pro, 16, 17) | 32,768 tokens | 4B | 50 messages |

The context size is clamped to a device-safe cap on every app launch to prevent OOM on devices that had a larger value stored from a previous install.

:::note
The 16K and 32K windows are only possible because of the **TurboQuant** KV cache compression built into LucidPal's llama.cpp fork. See [Architecture: TurboQuant](/architecture/turboquant).
:::

## Generation Timeout

Each response has a configurable timeout (default: **90 seconds**). If the model has not finished generating within the timeout, the partial response is preserved and an error is shown.

You can adjust this in **Settings → Generation Timeout**. Lowering it stops runaway responses faster; raising it helps with very long outputs on slower devices.

## Sampler Configuration

Default values — all three can be overridden in **Settings → Advanced**:

| Parameter          | Default | Reason                                 |
| ------------------ | ------- | -------------------------------------- |
| Temperature        | 0.35    | Low — reduces hallucinated JSON fields |
| Top-P              | 0.9     | Nucleus sampling                       |
| Max new tokens     | 768     | Prevents runaway generation            |
| Generation timeout | 90 s    | Cancels and preserves partial response |

## LlamaActor

`LlamaActor` is a Swift `actor` wrapping llama.cpp's C API. All calls are serialized — no concurrent inference, no data races on C pointers. It supports a dual-model architecture with separate text and vision model slots.

```swift
actor LlamaActor {
    // Separate pointers for text and vision models
    private var textModel: OpaquePointer?
    private var visionModel: OpaquePoctor?
    private var mtmdCtx: OpaquePointer?  // CLIP multimodal context

    func loadModel(at path: String, contextSize: UInt32, role: ModelType, ...) throws
    func unloadModel(role: ModelType)
    func unload()  // unloads both models
    func generate(prompt: String, role: ModelType, maxNew: Int32, ...) async
}
```

On devices with less than 6 GB RAM, loading a vision model while a text model is already loaded automatically unloads the text model first to avoid OOM.

:::warning
`LlamaActor` requires a physical device — the llama.cpp Metal backend does not run in the Simulator.
:::

## Error Handling

| Error                        | Source                                     | Handling                                     |
| ---------------------------- | ------------------------------------------ | -------------------------------------------- |
| `LLMError.modelNotLoaded`    | `LLMService.generate` when model not ready | ChatViewModel shows error banner             |
| `LLMError.timeout`           | Generation exceeds timeout                 | Partial response preserved, error shown      |
| `LLMError.generationInProgress` | Second generate() call while busy       | Silently rejected                            |
| `CancellationError`          | User taps stop button                      | Partial content left visible, no error shown |
| Any other `Error`            | llama.cpp runtime                          | Displayed in `messages[idx].content`         |
