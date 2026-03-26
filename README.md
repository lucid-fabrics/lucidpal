# LucidPal

An on-device AI assistant for iOS with native calendar access. All inference runs locally — no internet connection, no API keys, no data leaves your phone.

Powered by [Qwen3.5](https://huggingface.co/collections/unsloth/qwen35) and [llama.cpp](https://github.com/ggml-org/llama.cpp).

**[Documentation](https://lucid-fabrics.github.io/lucidpal)**

---

## Features

- **Fully on-device** — model runs in your iPhone's RAM, nothing is sent to any server
- **Calendar read & write** — create, rename, delete, or look up events; they appear instantly in the iOS Calendar app
- **Free time finder** — ask for a free slot and it checks your calendar for conflicts automatically
- **Conflict detection** — when a new or rescheduled event overlaps an existing one, a conflict banner appears on the card; tap it to keep the event, cancel it, or find an available slot; recurring events are identified separately
- **Multiple chat sessions** — create, rename, and switch between conversations; history is saved locally
- **Voice input** — tap the mic and speak your question; transcription runs on-device via WhisperKit
- **Voice auto-start** — optionally start listening automatically when opening a new chat
- **Thinking mode** — shows the model's reasoning process before answering (collapsible)
- **Configurable context window** — choose 2048, 4096, or 8192 tokens based on your device and conversation length
- **Siri shortcuts** — ask a question, check your schedule, add an event, or find free time hands-free
- **Copy messages** — long-press any bubble to copy the text

---

## Requirements

|              | Minimum                                                  |
| ------------ | -------------------------------------------------------- |
| iPhone       | Any model with 2 GB RAM (iPhone 12 or newer recommended) |
| iOS          | 16.0                                                     |
| Free storage | 1 GB (0.8B model), 2 GB (2B model), or 3 GB (4B model)   |

---

## Getting started

1. **Download the app** from the App Store _(coming soon)_
2. **Choose a model** — the app recommends one based on your device RAM
3. **Download** — the model fetches directly from Hugging Face (~0.5–2.5 GB, Wi-Fi recommended)
4. **Grant calendar access** — optional; required for reading/writing events
5. **Start chatting**

---

## Using the calendar

LucidPal can read your upcoming events and create or rename them on your behalf.

**Read:**

> "What do I have tomorrow?"

**Create:**

> "Schedule a dentist appointment Friday at 10am"

**Rename/update:**

> "Move my dentist appointment to 2pm"

A calendar card appears in the chat after every successful write. Tap it to open the Calendar app.

**Conflict detection:**

When a new or rescheduled event overlaps an existing one, an orange banner appears below the card:

> ⚠ Conflicts with 1 event — tap to review

Tapping the banner opens a sheet showing the conflicting event(s) — including title, time, calendar, and a "Recurring" badge when applicable — with three options:

| Action         | What it does                                                            |
| -------------- | ----------------------------------------------------------------------- |
| Keep Anyway    | Saves the event as-is and clears the warning                            |
| Find Free Slot | Searches the next 3 days for open windows matching the event's duration |
| Cancel Event   | Deletes the newly created event                                         |

Tapping a free slot reschedules the event to that time instantly.

---

## Siri

LucidPal registers shortcuts automatically. Use them from Siri, the Shortcuts app, or the Lock Screen:

| Phrase                           | What it does                                              |
| -------------------------------- | --------------------------------------------------------- |
| _"Ask LucidPal [question]"_      | Opens the app with your question pre-filled               |
| _"Check my LucidPal schedule"_   | Shows your upcoming calendar events                       |
| _"Add a LucidPal event"_         | Creates a calendar event via voice                        |
| _"Find free time in LucidPal"_   | Finds an open slot in your calendar                       |
| _"Delete event in LucidPal"_     | Deletes a named event with confirmation — no app required |
| _"Undo my last LucidPal action"_ | Reverses the last calendar change (in-app or via Siri)    |

The undo shortcut is context-aware: it knows whether your last action was a create, delete, or update — whether you did it inside LucidPal or through Siri — and reverses it with a confirmation card.

---

## Models

| Model               | Size    | Best for                |
| ------------------- | ------- | ----------------------- |
| Qwen3.5 0.8B Q4_K_M | 0.51 GB | Devices with 2–3 GB RAM |
| Qwen3.5 2B Q4_K_M   | 1.2 GB  | Devices with 3–5 GB RAM |
| Qwen3.5 4B Q4_K_M   | 2.5 GB  | Devices with 5 GB+ RAM  |

All models support Qwen3.5's built-in reasoning (thinking mode). Disable it in Settings for faster, more concise answers.

---

## Settings

| Setting                | What it does                                                                           |
| ---------------------- | -------------------------------------------------------------------------------------- |
| Calendar access        | Enable/disable calendar read & write in chat                                           |
| Default calendar       | Which calendar new events are added to                                                 |
| Thinking mode          | Show the model's reasoning before its answer (slower, more accurate)                   |
| Start voice on open    | Auto-start the microphone when opening a new chat                                      |
| Auto-send after speech | Submit automatically when speech recognition finishes                                  |
| Context window         | KV cache size in tokens (2048 / 4096 / 8192) — larger = longer conversations, more RAM |

Context window changes take effect the next time the model loads. Your device's RAM determines the maximum available size.

---

## Privacy

- No analytics, no tracking, no accounts
- The model file is stored in your app's private Documents folder
- Calendar data never leaves the device
- Microphone audio is transcribed on-device by [WhisperKit](https://github.com/argmaxinc/WhisperKit) and discarded immediately

---

## License

MIT
