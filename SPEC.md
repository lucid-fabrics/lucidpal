# LucidPal Vision — Feature Specification

## Overview

Enable LucidPal to accept photo attachments in chat. When an image is present, route to a vision-capable model (Qwen3-Vision). After processing, return to the text model for the response. Both models run on-device via llama.cpp.

---

## 1. Image Input & Preprocessing

### Detection

- `ChatViewModel` checks if the outgoing message contains image attachments (from `PHPickerViewController` or camera)
- Presence of any image → flag the generation as "vision mode"

### Preprocessing (before LLM call)

- Resize image to max **896×896** px (Qwen3-VL's preferred resolution)
- Convert to **JPEG** at quality **0.8**
- Base64-encode the image data
- Generate a low-quality **thumbnail** (224×224, JPEG 0.5) for display in chat bubble while processing

---

## 2. Model Management

### LlamaActor Changes

`LlamaActor` currently owns a single `OpaquePointer` pair (model + context). Extend it to support two models:

```swift
actor LlamaActor {
    nonisolated(unsafe) private var textModel: OpaquePointer?
    nonisolated(unsafe) private var textCtx: OpaquePointer?
    nonisolated(unsafe) private var visionModel: OpaquePointer?
    nonisolated(unsafe) private var visionCtx: OpaquePointer?

    private var currentModel: ModelType = .none  // .text, .vision, .none
}
```

### Model Switching

- `loadModel(at:role:)` — load a model into a specific slot (`text` or `vision`)
- `unloadModel(role:)` — unload a specific slot
- `isVisionModelLoaded: Bool`
- When switching: if the target model isn't loaded, load it; if the other model is loaded and RAM is tight, unload it
- Qwen3-Vision model file: same llama.cpp GGUF format, identified by filename convention (`*vision*.gguf`)

### RAM Management

- If total RAM < 6 GB: only keep one model loaded at a time (aggressive unload)
- If RAM ≥ 6 GB: keep both loaded simultaneously
- On `loadModel(at:role:)`, if OOM: unload the other model first, retry

---

## 3. Qwen3-VL Prompt Format

Qwen3-VL uses a special `<|vision|>` tag to insert image data:

```
<|im_start|>system
{system_prompt}<|im_end|>
<|im_start|>user
<|vision|>
Picture 1: <image_data>
<|vision|>
{user_text}<|im_end|>
<|im_start|>assistant
```

Where `<image_data>` is the base64-encoded JPEG prefixed with `data:image/jpeg;base64,`.

For **multiple images**, repeat the `<|vision|>...<|vision|>` block per image in order.

---

## 4. ChatMessage Model Update

```swift
struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    // ... existing fields ...

    /// Image attachments (local file URLs, not yet uploaded)
    var imageAttachments: [AttachedImage]

    /// True when this message was processed by the vision model
    var processedWithVision: Bool
}

struct AttachedImage: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let localURL: URL          // temporary file path
    let thumbnailData: Data?  // small preview
    let base64Data: String    // full JPEG base64 for LLM
    let width: Int
    let height: Int
}
```

---

## 5. ChatViewModel Changes

### Message Sending

```swift
func sendMessage(_ text: String, images: [UIImage]) async {
    let attachments = images.map { await preprocessImage($0) }
    let message = ChatMessage(
        role: .user,
        content: text,
        imageAttachments: attachments.map { AttachedImage(...) }
    )
    // ...

    let useVision = !attachments.isEmpty
    let model: ModelType = useVision ? .vision : .text
    let systemPrompt = await systemPromptBuilder.build()
    let stream = llamaService.generate(
        systemPrompt: systemPrompt,
        messages: conversationMessages,
        model: model  // new parameter
    )
}
```

### Generation API Change

Update `LLMServiceProtocol.generate` to accept a model role:

```swift
func generate(
    systemPrompt: String,
    messages: [ChatMessage],
    thinkingEnabled: Bool,
    modelRole: ModelType  // default .text
) -> AsyncThrowingStream<String, Error>
```

---

## 6. UI — Attachment Flow

### Attachment Button

- In chat input bar: add a **photo attachment button** (SF Symbol `photo.on.rectangle`)
- Tap → `PHPickerViewController` (multi-select enabled, filter: `.images`)
- Selected images appear as horizontal scrolling thumbnails below the input bar
- Tap thumbnail to remove

### Sending

- "vision" badge appears on send button when images are attached
- While vision model loads: show "Loading vision model…" in chat
- While processing: user bubble shows thumbnail + spinner

### Settings

- New toggle: **"Enable Vision"** (default: on)
- Model download section: add Qwen3-Vision to the model list alongside existing Qwen3 text models

---

## 7. Model Download

### UX

- Settings → "Download Models" → shows both text and vision models
- Vision model: `Qwen3-Vision-3B-F16.gguf` (approx 6–7 GB)
- Download via the same `ModelDownloadViewModel` flow used for text models

### Storage

- Vision GGUF stored in the same `ApplicationSupport/LucidPal/models/` directory
- Filename convention: `*vision*.gguf` triggers vision-mode eligibility

---

## 8. Error Handling

| Scenario                                      | Behavior                                                                      |
| --------------------------------------------- | ----------------------------------------------------------------------------- |
| Image present but vision model not downloaded | Show inline prompt: "Vision model needed — download?" with Settings deep-link |
| RAM OOM during vision model load              | Attempt to unload text model, retry once; if still OOM → error bubble         |
| Image decode failure                          | Show error: "Couldn't read image" — message sends without image               |
| Vision model fails mid-generation             | Fall back to text model with text-only prompt (image data dropped)            |

---

## 9. Testing Strategy

- Unit: `LlamaActor` vision load/unload/ro switching
- Unit: Image preprocessing (resize, base64 encode)
- Unit: Prompt building with image tags
- Integration: Send message with image → verify vision model path called
- Integration: Vision → text transition mid-conversation
- E2E (Playwright on iOS Simulator): Attach photo, send, verify response

---

## 10. File Changes

| File                                                     | Change                                                         |
| -------------------------------------------------------- | -------------------------------------------------------------- |
| `Sources/Models/ChatMessage.swift`                       | Add `AttachedImage`, `imageAttachments`, `processedWithVision` |
| `Sources/Services/LlamaActor.swift`                      | Dual-model support, vision mode                                |
| `Sources/Services/LLMService.swift`                      | Add `modelRole` param to `generate()`                          |
| `Sources/Services/LLMServiceProtocol.swift`              | Update protocol                                                |
| `Sources/ViewModels/ChatViewModel.swift`                 | Image attachment handling                                      |
| `Sources/ViewModels/ChatViewModel+MessageHandling.swift` | Vision routing                                                 |
| `Sources/Services/SystemPromptBuilder.swift`             | Vision tag insertion                                           |
| `Sources/Services/VisionImageProcessor.swift`            | **New** — resize, JPEG encode, base64                          |
| `Sources/Views/ChatInputBar.swift`                       | Photo attachment button + thumbnail strip                      |
| `Sources/Views/MessageBubbleView.swift`                  | Image attachment display                                       |
| `Sources/Views/SettingsView.swift`                       | Vision toggle + model download                                 |
| `Tests/`                                                 | Unit tests for image processing + vision prompt building       |
| `CLAUDE.md`                                              | Reference code-conventions                                     |

---

## 11. Out of Scope (v1)

- Multiple images in a single message (>5)
- Image editing / manipulation by the LLM
- Camera capture (only PHPicker gallery for now)
- Vision model streaming tokens (wait for full image analysis before first token)
