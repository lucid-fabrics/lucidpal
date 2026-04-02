---
sidebar_position: 1
---

# LucidPal

**On-device AI calendar assistant for iOS — fully private, no cloud, powered by Qwen3.5.**

## What is LucidPal?

LucidPal is an on-device AI assistant that understands and manages your iOS calendar through natural language. Every word is processed locally on your iPhone — no data ever leaves the device.

| Feature                  | Description                                                                                                 |
| ------------------------ | ----------------------------------------------------------------------------------------------------------- |
| **100% On-Device**       | All inference runs via llama.cpp on the Neural Engine. No API keys, no subscriptions, no internet required. |
| **Calendar Integration** | Create, update, delete and query events using plain English. Conflict detection included.                   |
| **Siri Shortcuts**       | Ten built-in Siri intents let you manage your calendar, notes, contacts, and habits without ever opening the app. |
| **Multi-Session**        | Full conversation history with named sessions, persisted locally across launches.                           |

## First-Run Experience

On first launch, LucidPal walks you through four onboarding screens:

| Step | Screen | What happens |
| ---- | ------ | ------------ |
| 1 | **Your Pocket AI** | Overview of on-device, no-cloud design |
| 2 | **Knows Your Schedule** | Introduction to calendar integration |
| 3 | **Type or Speak** | Mic and text input introduction |
| 4 | **Choose Your AI** | Select a text model (required) and an optional vision model, then download |

At the end of step 4, LucidPal requests **calendar** and **notification** permissions so the system prompts appear in context, before you enter the app for the first time.

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
