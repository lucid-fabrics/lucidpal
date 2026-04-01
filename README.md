<h1 align="center">
  <br>
  🧠 LucidPal
  <br>
</h1>

<p align="center">
  <strong>Your AI calendar assistant. Runs entirely on your iPhone.</strong><br>
  No internet. No API keys. No cloud. Your data stays on your device — always.
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

LucidPal is an AI assistant that lives entirely on your iPhone and knows your calendar. Ask it anything about your schedule, tell it to book something, or have it find you a free slot — it figures out the rest.

**You get:**
- A chat interface backed by a real LLM — running in your phone's RAM, not a server
- Full calendar read & write — events appear instantly in the iOS Calendar app
- Free time finder — asks about your day, finds the gaps, handles conflicts
- Voice input — speak your question, transcribed on-device by WhisperKit
- Siri shortcuts — trigger anything hands-free from the Lock Screen
- Multiple chat sessions with local history
- Home Screen widgets showing your upcoming events
- Live Activity on the Dynamic Island while you chat
- Pinned prompts and conversation templates for repeat workflows

No account. No subscription. No data leaving your phone.

---

## 🚀 Getting Started

1. **Download** from the App Store _(coming soon)_
2. **Pick a model** — the app recommends one based on your device RAM
3. **Download the model** — fetched directly from Hugging Face (~0.5–2.5 GB, Wi-Fi recommended)
4. **Grant calendar access** — optional; required for reading/writing events
5. **Start chatting**

> Built solo in my free time. If it saves you a meeting conflict or two, [a coffee helps](https://ko-fi.com/lucidfabrics). ☕

---

## 💬 Examples

**Check your schedule:**
> "What do I have tomorrow?"

> "Do I have anything this Friday afternoon?"

**Create an event:**
> "Schedule a dentist appointment Friday at 10am"

> "Add a team standup every Monday at 9am"

**Reschedule or update:**
> "Move my dentist appointment to 2pm"

> "Rename 'Meeting' to 'Design Review'"

**Find free time:**
> "When am I free for a 1-hour call this week?"

**General questions:**
> "Summarize my week"

> "What's my first meeting tomorrow and how long do I have before it?"

**Via Siri (hands-free):**
> "Ask LucidPal what I have tomorrow"

> "Check my LucidPal schedule"

> "Add a LucidPal event"

> "Find free time in LucidPal"

> "Delete event in LucidPal"

> "Undo my last LucidPal action"

---

## ⚡ Conflict Detection

When a new or rescheduled event overlaps something on your calendar, an orange banner appears on the card:

> ⚠ Conflicts with 1 event — tap to review

Tapping it opens a sheet with three options:

| Action | What it does |
|--------|-------------|
| **Keep Anyway** | Saves the event as-is |
| **Find Free Slot** | Searches the next 3 days for an open window |
| **Cancel Event** | Deletes the newly created event |

Tapping a free slot reschedules instantly.

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

All models support thinking mode — the model shows its reasoning before answering. Turn it off in Settings for faster, more concise replies.

---

## 🔒 Privacy

- No analytics, no tracking, no accounts
- The model runs in your app's private sandboxed container
- Calendar data never leaves the device
- Voice is transcribed on-device by [WhisperKit](https://github.com/argmaxinc/WhisperKit) and discarded immediately

---

## 💖 Support the Project

This project is free and open source. If it's useful to you, a star or a coffee keeps it moving.

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

MIT
