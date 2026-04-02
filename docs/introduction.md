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
| **Vision / Photo Analysis**   | Describe images and photos using an optional on-device vision model (Qwen3-VL). See the [Models guide](./guides/models). |

## First-Run Experience

On first launch, LucidPal walks you through four onboarding screens:

| Step | Screen | What happens |
| ---- | ------ | ------------ |
| 1 | **Your Pocket AI** | Overview of on-device, no-cloud design |
| 2 | **Knows Your Schedule** | Introduction to calendar integration |
| 3 | **Type or Speak** | Mic and text input introduction |
| 4 | **Choose Your AI** | Select a text model (required) and an optional vision model, then download |

At the end of step 4, LucidPal requests **calendar** and **notification** permissions so the system prompts appear in context, before you enter the app for the first time.

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
