---
sidebar_position: 1
---

# LucidPal

**On-device AI calendar assistant for iOS — fully private, no cloud, powered by Qwen3.5.**

## What is LucidPal?

LucidPal is an on-device AI assistant that understands and manages your iOS calendar through natural language. Every word is processed locally on your iPhone — no data ever leaves the device.

| Feature                       | Description                                                                                                 |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **100% On-Device**            | All inference runs via llama.cpp on the Neural Engine. No API keys, no subscriptions, no internet required. |
| **Calendar Integration**      | Create, update, delete and query events using plain English. Conflict detection included.                   |
| **Siri Shortcuts**            | Ten built-in Siri intents let you manage your calendar, notes, contacts, and habits without ever opening the app. |
| **Multi-Session**             | Full conversation history with named sessions, persisted locally across launches.                           |
| **Notes**                     | Capture quick thoughts in chat; notes are enriched and stored locally. See the [Notes guide](./guides/notes). |
| **Habit Tracker**             | Track daily habits and log streaks through natural language. See the [Habits guide](./guides/habit-tracker). |
| **Document Summarization**    | Summarize PDFs and text files entirely on-device. See the [Document Summarization guide](./guides/document-summarization). |
| **Web Search**                | Query DuckDuckGo, Brave, or a self-hosted SearXNG instance — results synthesized locally. See the [Web Search guide](./guides/web-search). |
| **Vision / Photo Analysis**   | Describe images and photos using an optional on-device vision model (Qwen3.5 Vision 4B). See the [Vision & Photos guide](./guides/vision-photos). |
| **Contacts**                  | Look up phone numbers and email addresses from your contacts in chat. See the [Contacts guide](./guides/contacts). |
| **Reminders**                 | Set one-off reminders through natural language — synced to the iOS Reminders app. See the [Reminders guide](./guides/reminders). |
| **Productivity Features**     | AI actions for notes and habits from chat, conversation export, full-text message search, and pinned prompts. See the [Productivity guide](./guides/productivity-features). |
| **Widgets & Notifications**   | Home-screen widgets and pre-event push notifications. See the [Widgets guide](./guides/widgets-notifications). |
| **Live Activity & Templates** | Dynamic Island / Live Activity during generation, plus conversation templates. See the [Templates guide](./guides/templates-live-activity). |
| **Settings**                  | Full reference for every setting in the app. See the [Settings guide](./guides/settings). |
| **Privacy**                   | Full explanation of the on-device architecture and what data never leaves your phone. See the [Privacy guide](./guides/privacy). |
| **Models**                    | How to download, switch, and manage GGUF models from the app. See the [Models guide](./guides/models). |
| **Accessibility**             | VoiceOver support, Dynamic Type, Reduce Motion, and other accessibility features. See the [Accessibility guide](./guides/accessibility). |

## Quick Start

1. **Download LucidPal** from the App Store and open it.
2. **Download an AI model** — pick the recommended model for your device on the "Choose Your AI" screen and tap **Download & Get Started**.
3. **Grant calendar permission** — LucidPal will ask during onboarding so it can read and write your events.
4. **Start chatting** — type or tap the mic and ask anything: *"What do I have tomorrow?"*, *"Schedule a dentist appointment Friday at 3 pm"*, or *"Clear my Tuesday afternoon."*

## First-Run Experience

On first launch, LucidPal walks you through five onboarding screens:

| Step | Screen | What happens |
| ---- | ------ | ------------ |
| 1 | **Your Pocket AI** | Overview of on-device, no-cloud design |
| 2 | **Knows Your Schedule** | Introduction to calendar integration |
| 3 | **Type or Speak** | Mic and text input introduction |
| 4 | **Choose Your AI** | Select a text model (required) and an optional vision model, then download |
| 5 | **Data Sources** | Enable Notes, Habits, Contacts, Calendar, Location, and Web Search. iOS permission prompts for Calendar, Contacts, and Location appear inline so you can grant access in context before entering the app. |

After step 5, you are taken directly into the app with all selected permissions granted.

## Device Requirements

LucidPal runs the AI model entirely on-device and requires **at least 6 GB of RAM**. Devices with less RAM are not supported and will see an informational screen explaining the requirement.

| Device | RAM | Supported |
|--------|-----|-----------|
| iPhone 12 Pro / 12 Pro Max | 6 GB | ✅ Yes |
| iPhone 13 series (all models) | 4–6 GB | ✅ Yes (13 Pro/Pro Max have 6 GB) |
| iPhone 14 series and later | 6 GB+ | ✅ Yes |
| iPhone 16 series and later | 8 GB+ | ✅ Yes |
| iPhone 12 / 12 mini | 4 GB | ❌ No |
| iPhone 11 and earlier | ≤4 GB | ❌ No |

:::note
The standard **iPhone 12** and **iPhone 12 mini** have only 4 GB of RAM and are **not supported**, even though they run a compatible iOS version. The iPhone 12 Pro and 12 Pro Max (6 GB) are fully supported.
:::

The minimum iOS version required is **iOS 16** (for AppIntents/Siri Shortcuts support). iOS 17 or later is recommended.

---

## Models

LucidPal ships with three GGUF model options, automatically selected based on device RAM:

| Model        | Size    | Min RAM | Recommended for                      |
| ------------ | ------- | ------- | ------------------------------------ |
| Qwen3.5 0.8B | 0.51 GB | 2 GB    | Older iPhones with limited RAM       |
| Qwen3.5 2B   | 1.2 GB  | 3 GB    | Default — iPhone 12 / 13 and similar |
| Qwen3.5 4B   | 2.5 GB  | 5 GB    | iPhone 14 Pro / 15 / 16 and newer    |

All three models run natively via [llama.cpp](https://github.com/ggml-org/llama.cpp) with Metal GPU acceleration.

## Tech Stack

| Layer        | Technology                              |
| ------------ | --------------------------------------- |
| Language     | Swift 5.10 + SwiftUI                    |
| LLM Runtime  | llama.cpp (C FFI via Swift actor)       |
| Calendar     | EventKit (wrapped in CalendarService)   |
| Speech       | AVFoundation + SFSpeechRecognizer       |
| Vision       | llama.cpp multimodal (optional GGUF)    |
| Siri         | AppIntents framework                    |
| Persistence  | Custom JSON session store               |
| Testing      | XCTest with full mock infrastructure    |
