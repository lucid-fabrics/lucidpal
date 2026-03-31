# LucidPal

An on-device AI assistant for iOS with native calendar access. All inference runs locally — no internet connection, no API keys, no data leaves your phone.

Powered by [Qwen3.5](https://huggingface.co/collections/unsloth/qwen35) and [llama.cpp](https://github.com/ggml-org/llama.cpp).

**[Full documentation →](https://lucid-fabrics.github.io/lucidpal)**

---

## Features

- **Fully on-device** — model runs in your iPhone's RAM, nothing is sent to any server
- **Calendar read & write** — create, rename, delete, or look up events; they appear instantly in the iOS Calendar app
- **Free time finder** — ask for a free slot and it checks your calendar for conflicts automatically
- **Conflict detection** — when a new or rescheduled event overlaps an existing one, a conflict banner appears on the card
- **Multiple chat sessions** — create, rename, and switch between conversations; history is saved locally
- **Voice input** — tap the mic and speak your question; transcription runs on-device via WhisperKit
- **Siri shortcuts** — ask a question, check your schedule, add an event, or find free time hands-free
- **Pinned prompts** — pin frequently used questions; tap to reuse in one tap
- **Conversation templates** — save and reuse chat session starters for repeated workflows
- **Event reminders** — push notifications 10 minutes before upcoming calendar events
- **Live Activity** — see the current session on the Dynamic Island and Lock Screen
- **Home Screen widgets** — small, medium, and large widgets showing your upcoming calendar

---

## Requirements

|              | Minimum                                                   |
| ------------ | --------------------------------------------------------- |
| iPhone       | Any model with 2 GB RAM (iPhone 12 or newer recommended)  |
| iOS          | 16.0                                                      |
| Free storage | 1 GB (0.8B model), 2 GB (2B model), or 3 GB (4B model)    |

---

## Getting started

1. **Download** from the App Store _(coming soon)_
2. **Choose a model** — the app recommends one based on your device RAM
3. **Grant calendar access** — optional; required for reading/writing events
4. **Start chatting**

---

## Models

| Model               | Size    | Best for                |
| ------------------- | ------- | ----------------------- |
| Qwen3.5 0.8B Q4_K_M | 0.51 GB | Devices with 2–3 GB RAM |
| Qwen3.5 2B Q4_K_M   | 1.2 GB  | Devices with 3–5 GB RAM |
| Qwen3.5 4B Q4_K_M   | 2.5 GB  | Devices with 5 GB+ RAM  |

---

## Privacy

- No analytics, no tracking, no accounts
- Calendar data never leaves the device
- Microphone audio is transcribed on-device by [WhisperKit](https://github.com/argmaxinc/WhisperKit) and discarded immediately

---

## License

MIT
