# PocketMind

An on-device AI assistant for iOS with native calendar access. All inference runs locally — no internet connection, no API keys, no data leaves your phone.

Powered by [Qwen3](https://huggingface.co/Qwen) and [llama.cpp](https://github.com/ggml-org/llama.cpp).

**[Documentation](https://lucid-fabrics.github.io/pocketmind)**

---

## Features

- **Fully on-device** — model runs in your iPhone's RAM, nothing is sent to any server
- **Calendar read & write** — create, rename, delete, or look up events; they appear instantly in the iOS Calendar app
- **Free time finder** — ask for a free slot and it checks your calendar for conflicts automatically
- **Multiple chat sessions** — create, rename, and switch between conversations; history is saved locally
- **Voice input** — tap the mic and speak your question
- **Thinking mode** — shows the model's reasoning process before answering (collapsible)
- **Siri shortcuts** — ask a question, check your schedule, add an event, or find free time hands-free
- **Copy messages** — long-press any bubble to copy the text

---

## Requirements

| | Minimum |
|---|---|
| iPhone | Any model with 4 GB RAM (iPhone 12 or newer recommended) |
| iOS | 16.0 |
| Free storage | 2 GB (1.7B model) or 3 GB (4B model) |

---

## Getting started

1. **Download the app** from the App Store *(coming soon)*
2. **Choose a model** — the app recommends one based on your device RAM
3. **Download** — the model fetches directly from Hugging Face (~1.8–2.5 GB, Wi-Fi recommended)
4. **Grant calendar access** — optional; required for reading/writing events
5. **Start chatting**

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

PocketMind registers four shortcuts automatically. Use them from Siri, the Shortcuts app, or the Lock Screen:

| Phrase | What it does |
|--------|--------------|
| *"Ask PocketMind [question]"* | Opens the app with your question pre-filled |
| *"Check my PocketMind schedule"* | Shows your upcoming calendar events |
| *"Add a PocketMind event"* | Creates a calendar event via voice |
| *"Find free time in PocketMind"* | Finds an open slot in your calendar |

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

## License

MIT
