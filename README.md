<h1 align="center">
  <br>
  🧠 LucidPal
  <br>
</h1>

<p align="center">
  <strong>A private AI assistant that lives on your iPhone and actually does things.</strong><br>
  Manages your calendar, notes, and habits. Searches the web. Analyzes photos.<br>
  All on-device. No cloud. No accounts. No data leaving your phone.
</p>

<p align="center">
  <img alt="iOS" src="https://img.shields.io/badge/iOS-16%2B-111111?logo=apple&logoColor=white">
  <img alt="On-device AI" src="https://img.shields.io/badge/AI-On--Device-34C759?logo=llama&logoColor=white">
  <a href="https://lucid-fabrics.github.io/lucidpal/">
    <img alt="Documentation" src="https://img.shields.io/badge/Docs-Read%20the%20Docs-blue?logo=readthedocs&logoColor=white">
  </a>
  <a href="https://ko-fi.com/lucidfabrics">
    <img alt="Support on Ko-fi" src="https://img.shields.io/badge/Support-Ko--fi-FF5E5B?logo=ko-fi&logoColor=white">
  </a>
  <a href="https://buymeacoffee.com/lucidfabrics">
    <img alt="Buy Me a Coffee" src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?logo=buymeacoffee&logoColor=black">
  </a>
</p>

---

## 🧰 What It Does

LucidPal is an agentic AI assistant that runs fully on-device via [llama.cpp](https://github.com/ggml-org/llama.cpp). It doesn't just answer questions — it takes action. Book a meeting, save a note, log a habit, look up a contact, search the web, or analyze a photo. All from a single chat.

**You get:**
- **On-device LLM inference** — runs on your Neural Engine, not a server
- **Calendar management** — create, update, delete, and query events in plain English
- **Notes** — ask it to save ideas, and they persist in a dedicated tab
- **Habit tracking** — log workouts, habits, streaks — from chat or the dashboard
- **Contacts** — look up phone numbers, emails by name
- **Web search** — real-time weather, news, stocks, flights — no separate app needed
- **Vision** — attach a photo and ask anything about it
- **Siri Shortcuts** — trigger actions hands-free from the Lock Screen
- **Home Screen widgets** and **Live Activity** on the Dynamic Island
- **Multiple chat sessions** with persistent local history
- **Thinking mode** — see the model's reasoning before its answer

No subscription. No API key. No account. Zero telemetry.

> Built solo. If it's useful, [a coffee helps](https://ko-fi.com/lucidfabrics). ☕

---

## 🚀 Getting Started

1. **Download** from the App Store _(coming soon)_
2. **Pick a model** — the app recommends one based on your device RAM
3. **Download the model** — fetched from Hugging Face (~0.5–2.5 GB, Wi-Fi recommended)
4. **Grant access** — calendar, contacts, microphone — all optional, all on-device
5. **Start chatting**

---

## 💬 Examples

**Calendar:**
> "What do I have tomorrow?"

> "Schedule a dentist appointment Friday at 10am"

> "When am I free for a 1-hour call this week?"

**Notes:**
> "Save this: call the landlord about the leak"

> "What did I note about the project last week?"

**Habits:**
> "Log my workout for today"

> "How's my meditation streak?"

**Web search:**
> "What's the weather this weekend?"

> "Any news on the Apple event?"

**Vision:**
> "What's in this photo?" _(attach an image)_

> "Read the text from this receipt"

**Via Siri (hands-free):**
> "Ask LucidPal what I have tomorrow"

> "Find free time in LucidPal"

> "Undo my last LucidPal action"

---

## 📋 Requirements

|              | Minimum                                                   |
| ------------ | --------------------------------------------------------- |
| iPhone       | Any model with 2 GB RAM (iPhone 12 or newer recommended)  |
| iOS          | 16.0                                                      |
| Free storage | 1 GB (0.8B model), 2 GB (2B model), or 3 GB (4B model)    |

---

## 🤖 Models

| Model               | Size    | Best for                |
| ------------------- | ------- | ----------------------- |
| Qwen3.5 0.8B Q4_K_M | 0.51 GB | Devices with 2–3 GB RAM |
| Qwen3.5 2B Q4_K_M   | 1.2 GB  | Devices with 3–5 GB RAM |
| Qwen3.5 4B Q4_K_M   | 2.5 GB  | Devices with 5 GB+ RAM  |

All models support thinking mode. Disable it in Settings for faster, more concise answers.

---

## 🔒 Privacy

- No analytics, no tracking, no accounts
- All inference runs on your device — nothing is sent to any server
- Calendar, contacts, and notes never leave your phone
- Voice is transcribed on-device by [WhisperKit](https://github.com/argmaxinc/WhisperKit) and discarded immediately
- Web search is opt-in and scoped to your query only

---

## 💖 Support the Project

LucidPal is free to use. If it saves you time or you want to support what's coming next, a coffee goes a long way.

<p align="center">
  <a href="https://ko-fi.com/lucidfabrics">
    <img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi">
  </a>
</p>

<p align="center">
  <a href="https://buymeacoffee.com/lucidfabrics">
    <img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?logo=buymeacoffee&logoColor=black" alt="Buy Me a Coffee">
  </a>
</p>

---

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=lucid-fabrics/lucidpal&type=date)](https://www.star-history.com/#lucid-fabrics/lucidpal&type=date)

---

## License

All rights reserved. LucidPal is free to use. Premium features are coming.
