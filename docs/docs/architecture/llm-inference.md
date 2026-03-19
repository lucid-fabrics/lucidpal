---
sidebar_position: 2
---

# LLM Inference

How PocketMind streams tokens from llama.cpp to the SwiftUI UI.

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

## Thinking Mode (Qwen3 `<think>` Tags)

Qwen3 models emit a `<think>...</think>` block before answering. PocketMind handles this live:

```
<think>
The user wants to create an event...
</think>
Here's your event — tap confirm.
```

`applyStreamToken()` buffers the prefix and splits at `</think>`:

| Buffer state | Action |
|--------------|--------|
| Starts with `<think>` (no close yet) | Set `isThinking = true`, show in ThinkingDisclosure |
| `</think>` detected | Extract thinking text, reset to response mode |
| No `<think>` prefix | Treat entire output as response |

## Context Window

Context size is chosen based on device RAM at launch:

```swift
let ramGB = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
let historyLimit = ramGB >= 6
    ? ChatConstants.largeHistoryLimit   // 50 messages ≈ 5 000 tokens
    : ChatConstants.smallHistoryLimit   // 20 messages ≈ 2 000 tokens
```

| RAM | Context | History Limit |
|-----|---------|---------------|
| < 6 GB | 4K tokens | 20 messages |
| ≥ 6 GB | 8K tokens | 50 messages |

## Sampler Configuration

| Parameter | Value | Reason |
|-----------|-------|--------|
| Temperature | 0.35 | Low — reduces hallucinated JSON fields |
| Top-P | 0.9 | Nucleus sampling |
| Max new tokens | 768 | Prevents runaway generation |

## LlamaActor

`LlamaActor` is a Swift `actor` wrapping llama.cpp's C API. All calls are serialized — no concurrent inference, no data races on C pointers.

```swift
actor LlamaActor {
    private var model: OpaquePointer?
    private var context: OpaquePointer?

    func load(path: String) throws { ... }
    func unload() { ... }
    func generate(tokens: [Int32], maxNew: Int) async throws -> AsyncThrowingStream<String, Error>
}
```

:::warning
`LlamaActor` requires a physical device — the llama.cpp Metal backend does not run in the Simulator.
:::

## Error Handling

| Error | Source | Handling |
|-------|--------|---------|
| `LLMError.modelNotLoaded` | `LLMService.generate` when model not ready | ChatViewModel shows error banner |
| `CancellationError` | User taps stop button | Partial content left visible, no error shown |
| Any other `Error` | llama.cpp runtime | Displayed in `messages[idx].content` |
