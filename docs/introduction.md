---
sidebar_position: 1
---

# LucidPal

**On-device AI calendar assistant for iOS — powered by Qwen3, with optional cloud AI via Gemini.**

## What is LucidPal?

LucidPal is an on-device AI assistant that understands and manages your iOS calendar through natural language. Every word is processed locally on your iPhone — no data ever leaves the device.

| Feature                       | Description                                                                                                 |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **100% On-Device**            | All inference runs via llama.cpp on the Neural Engine. No API keys required for local AI. Optional cloud AI available with subscription. |
| **Cloud AI**                  | Optional cloud AI powered by Gemini 2.5 Flash. Available for Starter and higher subscribers. Automatically switches to local when offline. |
| **Calendar Integration**      | Create, update, delete, reschedule, and query events using plain English. Conflict detection included.                   |
| **Siri Shortcuts**            | Eleven built-in Siri intents let you manage your calendar, notes, contacts, and habits without ever opening the app. |
| **Multi-Session**             | Full conversation history with named sessions, persisted locally across launches.                           |
| **Notes**                     | Capture quick thoughts in chat; notes are enriched and stored locally. See the [Notes guide](./guides/notes). |
| **Habit Tracker**             | Track daily habits and log streaks through natural language. See the [Habits guide](./guides/habits). |
| **Vision / Photo Analysis**   | Describe images and photos using an optional on-device vision model. See the [Models guide](./guides/models). |
| **Proactive AI**              | Daily morning briefing notification via background refresh. Tap to launch Agent Mode.                       |
| **Premium Tiers**             | Starter, Pro, and Ultimate plans with cloud AI credits, live activities, smart widgets, and more.          |
| **Live Activities**           | Dynamic Island and Lock Screen Live Activity during AI generation.                                          |
| **Widgets & Notifications**   | Home-screen widgets and pre-event push notifications. See the [Widgets guide](./guides/widgets-notifications). |
| **Contacts**                  | Look up phone numbers and email addresses from your contacts in chat. |
| **Reminders**                 | Set one-off reminders through natural language — synced to the iOS Reminders app. |
| **Web Search**                | Query DuckDuckGo, Brave, or a self-hosted SearXNG instance — results synthesized locally. |
| **Conversation Templates**    | Built-in AI personas (Writing Coach, Decision Helper, Meeting Prep, Brainstorm) for focused sessions.       |
| **Productivity Features**     | AI actions for notes and habits from chat, conversation export, full-text message search, and pinned prompts. |
| **Settings**                  | Full reference for every setting in the app. See the Settings section within the app. |
| **Privacy**                   | Full explanation of the on-device architecture and what data never leaves your phone. See the [Privacy guide](./guides/privacy). |
| **Models**                    | How to download, switch, and manage GGUF models from the app. See the [Models guide](./guides/models). |

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

LucidPal runs the AI model on-device via llama.cpp with Metal GPU acceleration and supports all iPhones with 2 GB+ RAM:

| Device RAM | Supported model | Status |
|------------|-----------------|--------|
| 2–3 GB     | Qwen3.5 0.8B    | ✅ Supported |
| 3–5 GB     | Qwen3.5 2B      | ✅ Supported |
| 5 GB+      | Qwen3.5 4B or Vision 4B | ✅ Recommended |

The minimum iOS version is **iOS 16** (for AppIntents/Siri Shortcuts support). iOS 17 or later is recommended for the best experience.

---

## Models

LucidPal ships with four built-in GGUF models, automatically selected based on device RAM:

| Model | Size | Min RAM | Capabilities |
|-------|------|---------|-------------|
| Qwen3.5 0.8B | 0.51 GB | 2 GB | Text only |
| Qwen3.5 2B | 1.2 GB | 3 GB | Text only |
| Qwen3.5 4B | 2.5 GB | 5 GB | Text only |
| Qwen3.5 4B Vision | 2.5 GB | 5 GB | Text + Vision (integrated) |

See the [Models guide](./guides/models) for full details.

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
