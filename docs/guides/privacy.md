---
sidebar_position: 5
---

# Privacy

How LucidPal keeps your data entirely on your device.

## Fully On-Device

Every word you type, every calendar event you manage, and every AI response is processed **locally on your iPhone**. Nothing leaves your device.

- No account required
- No API keys
- No subscription
- No internet connection needed to use the AI

---

## What LucidPal Accesses

| Data                  | Used for                         | Leaves device? |
| --------------------- | -------------------------------- | -------------- |
| Your messages         | On-device AI inference           | Never          |
| Calendar events       | Reading and writing via EventKit | Never          |
| Microphone (optional) | Speech-to-text recognition       | Never          |
| Device RAM            | Selecting the right AI model     | Never          |

---

## Calendar Access

LucidPal requests access to your iOS calendar via **EventKit** — the same system framework used by the built-in Calendar app. You control which calendars are accessible through iOS Settings.

To grant or revoke access: **iOS Settings → Privacy & Security → Calendars → LucidPal**

---

## Speech Recognition

If you use the microphone button in LucidPal, speech recognition runs **on-device** via **WhisperKit** (OpenAI Whisper tiny model, downloaded once and stored locally). Audio is recorded to a temporary file, transcribed on-device, and then deleted. Audio is never sent to a server.

Microphone access is optional. The app works fully without it.

---

## Conversation History

Your chat sessions are saved locally in the app's private storage on your device. They are:

- Not backed up to iCloud by default
- Not synced across devices
- Deleted permanently when you delete a session or the app

---

## The AI Model

The Qwen3.5 model files are stored locally after download. Once downloaded, LucidPal works completely offline. The model weights are never sent anywhere — all inference runs via **llama.cpp** with Metal GPU acceleration directly on your iPhone's Neural Engine.

---

## No Analytics

LucidPal collects no analytics, no crash reports, and no usage data. There is no telemetry of any kind.
