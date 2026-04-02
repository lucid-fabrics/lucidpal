---
sidebar_position: 5
---

# Privacy

How LucidPal keeps your data entirely on your device.

## Fully On-Device

Every word you type, every calendar event you manage, and every AI response is processed **locally on your iPhone**. Nothing leaves your device.

- No account required
- No API keys for AI inference
- No subscription
- No internet connection needed to use the AI (after initial model download)

---

## What LucidPal Accesses

| Data                        | Used for                              | Leaves device? |
| --------------------------- | ------------------------------------- | -------------- |
| Your messages               | On-device AI inference                | Never          |
| Calendar events             | Reading and writing via EventKit      | Never          |
| Photos / images (optional)  | On-device vision analysis             | Never          |
| Microphone (optional)       | Speech-to-text recognition            | Never          |
| Contacts (optional)         | Looking up contacts via Siri          | Never          |
| Notifications (optional)    | Reminders and alerts                  | Never          |
| Device RAM                  | Selecting the right AI model          | Never          |

---

## Calendar Access

LucidPal requests access to your iOS calendar via **EventKit** — the same system framework used by the built-in Calendar app. You control which calendars are accessible through iOS Settings.

To grant or revoke access: **iOS Settings → Privacy & Security → Calendars → LucidPal**

---

## Speech Recognition

If you use the microphone button in LucidPal, speech recognition runs **on-device** via Apple's `SFSpeechRecognizer`. Audio is never sent to a server.

Microphone access is optional. The app works fully without it.

---

## Conversation History

Your chat sessions are saved locally in the app's private storage on your device. They are:

- Not backed up to iCloud by default
- Not synced across devices
- Deleted permanently when you delete a session or the app

---

## The AI Model

The Qwen3.5 model files are downloaded once from **HuggingFace** (`huggingface.co`) and stored locally on your device. Once downloaded, LucidPal works completely offline — no internet connection is needed for AI inference. The model weights are never sent anywhere — all inference runs via **llama.cpp** with Metal GPU acceleration directly on your iPhone's Neural Engine.

---

## Vision and Photo Analysis

If you use the optional vision model, any photos or images you share are processed entirely **on-device** by the vision model. Images are resized and passed to the local model for analysis — they are never uploaded to any server.

To enable vision: select a vision model during onboarding or in [**Settings**](./settings) → **AI Model**. See the [Vision & Photos guide](./vision-photos) for full details.

---

## Web Search (Optional)

Web search is **off by default**. When enabled, LucidPal supports three providers:

| Provider | What is sent externally | To whom |
|----------|-------------------------|---------|
| DuckDuckGo (default) | Search query only | DuckDuckGo (`html.duckduckgo.com`) |
| Brave Search | Search query + your API key | Brave (`api.search.brave.com`) |
| SearXNG | Search query only | Your own self-hosted instance |

Your messages, calendar data, and conversation history are **never** included in search requests — only the query text extracted by the AI is sent.

The Brave API key is stored only on your device (iOS Keychain via `UserDefaults`). It is never transmitted to Anthropic or to LucidPal servers.

---

## lucidpal.app Web Services (Optional)

A separate cloud backend (`lucidpal-api`) powers the **lucidpal.app** website and web app only. It handles account authentication, billing, notes sync, and habits tracking for web users.

**The iOS app does not connect to this backend.** All iOS features (calendar, AI inference, voice) run fully offline. The API is only relevant if you also use the web app at [lucidpal.app](https://lucidpal.app).

---

## No Analytics

LucidPal collects no analytics, no crash reports, and no usage data. There is no telemetry of any kind.
