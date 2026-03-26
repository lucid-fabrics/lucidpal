# LucidPal — Claude Code Instructions

## Code Conventions

Reference: `~/git/code-conventions/`

**MANDATORY COMPLIANCE** — follow all conventions in `~/git/code-conventions/` without exception.

## Project Context

- **Type:** Native iOS app (Swift/SwiftUI)
- **LLM:** On-device llama.cpp (GGUF models)
- **Architecture:** Nx monorepo (single `lucidpal-ios` app)
- **Stack:** SwiftUI, Combine, EventKit, StoreKit

## Vision Feature

When adding vision-related code:

- Image preprocessing: resize to 896×896 JPEG 0.8, base64 encode
- Qwen3-VL uses `<|vision|><|image_1|>base64_data<|vision|>` prompt format
- Dual-model: text model (`Qwen3-*.gguf`) + vision model (`*vision*.gguf`)
- LlamaActor manages model loading/unloading per role
- `ModelType` enum: `.text` vs `.vision`

## Testing

- Unit tests required for new services
- Test image processing with `VisionImageProcessorTests`
- Mock `LLMServiceProtocol` for integration tests

## Build & Deploy

```bash
# Build
xcodebuild -project apps/lucidpal-ios/LucidPal.xcodeproj \
  -scheme LucidPal -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Test
xcodebuild test -project apps/lucidpal-ios/LucidPal.xcodeproj \
  -scheme LucidPal -destination 'platform=iOS Simulator,name=iPhone 16'
```
