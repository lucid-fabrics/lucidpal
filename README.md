# PocketMind

An on-device AI assistant for iOS with native calendar access. All inference runs locally — no internet connection, no API keys, no data leaves your phone.

Powered by [Qwen3](https://huggingface.co/Qwen) and [llama.cpp](https://github.com/ggml-org/llama.cpp).

---

## Features

- **Fully on-device** — model runs in your iPhone's RAM, nothing is sent to any server
- **Calendar read & write** — ask it to create, rename, or look up events; they appear instantly in the iOS Calendar app
- **Voice input** — tap the mic and speak your question
- **Thinking mode** — shows the model's reasoning process before answering (collapsible)
- **Siri shortcut** — say *"Hey Siri, ask PocketMind [anything]"* to open the app with your query pre-filled
- **Copy messages** — long-press any bubble to copy the text

---

## Requirements

| | Minimum |
|---|---|
| iPhone | Any model with 4 GB RAM (iPhone 12 or newer recommended) |
| iOS | 16.0 |
| Free storage | 2 GB (1.7B model) or 3 GB (4B model) |
| Xcode | 15 or later (to build from source) |

---

## Installation

PocketMind is not on the App Store. You build it yourself in Xcode.

### 1. Clone the repo

```bash
git clone https://github.com/wassimmehanna/pocketmind.git
cd pocketmind/apps/pocketmind-ios
```

### 2. Generate the Xcode project

```bash
brew install xcodegen   # one-time
xcodegen generate
```

### 3. Open in Xcode

```bash
open PocketMind.xcodeproj
```

### 4. Set your Team

In Xcode → select the **PocketMind** target → **Signing & Capabilities** → set your Apple ID as the team.

### 5. Build & run on your iPhone

Connect your iPhone, select it as the run destination, press **⌘R**.

> On first launch, go to **Settings → General → VPN & Device Management** and trust your developer certificate.

---

## First launch

1. **Choose a model** — the app recommends one based on your device RAM
2. **Download** — the model downloads directly from Hugging Face (~1.8–2.5 GB)
3. **Grant calendar access** — optional; required for reading/writing events
4. **Start chatting**

---

## Using the calendar

PocketMind can read your upcoming events and create or rename them on your behalf.

**Read:**
> "What do I have tomorrow?"

**Create:**
> "Schedule a dentist appointment Friday at 10am"

**Rename/update:**
> "Move my dentist appointment to 2pm"

A calendar card appears in the chat after every successful write. Tap it to open the Calendar app.

---

## Siri

After installing, add the shortcut via the Shortcuts app or just say:

> **"Hey Siri, ask PocketMind [your question]"**

Siri will open PocketMind with your question ready to send.

---

## Models

| Model | Size | Best for |
|-------|------|----------|
| Qwen3 1.7B Q8_0 | 1.83 GB | Devices with 4–6 GB RAM |
| Qwen3 4B Q4_K_M | 2.5 GB | Devices with 6 GB+ RAM |

Both models support Qwen3's built-in reasoning (thinking mode). Disable it in Settings for faster, more concise answers.

---

## Privacy

- No analytics, no tracking, no accounts
- The model file is stored in your app's private Documents folder
- Calendar data never leaves the device
- Microphone audio is processed on-device by Apple's Speech framework and discarded immediately

---

## Building with Fastlane (optional)

```bash
gem install bundler
cd apps/pocketmind-ios
bundle install
bundle exec fastlane ios device   # build + install on connected iPhone
```

---

## License

MIT
