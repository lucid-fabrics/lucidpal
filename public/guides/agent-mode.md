---
sidebar_position: 21
---

# Agent Mode

Let LucidPal act on your behalf — plan tasks, query your data, and take multi-step actions using voice or text.

---

## What Is Agent Mode?

Agent Mode turns LucidPal into an autonomous assistant that can reason across multiple tools to answer a question or complete a task. Instead of a back-and-forth chat, you describe what you want and the agent figures out which tools to call, runs them in sequence, and returns a single coherent answer.

Internally, the agent follows a **plan → tool call → observe → repeat** loop until it has enough information to produce a final response.

---

## Opening Agent Mode

Tap the **microphone** button on the home screen. The Agent Mode sheet slides up with:

- A row of **ability plan chips** — pre-built task shortcuts for common requests.
- A **text input bar** for free-form queries.
- A **doc icon** in the input bar to attach files (see [Documents in Agent Mode](#documents-in-agent-mode)).

---

## Ability Plan Chips

Chips are one-tap shortcuts that pre-fill a well-defined task prompt. Tap any chip to submit it immediately — no typing required.

| Chip | What the agent does |
|---|---|
| Morning Briefing | Summarizes today's calendar events, top habits due, and unread Gmail highlights |
| What's on today? | Lists all calendar events and reminders for the current day |
| Plan my day | Suggests a time-blocked schedule based on your events and free slots |
| Find a free slot | Scans your calendar and proposes the next available 30-minute window |
| How did I sleep? | Reads last night's sleep data from Apple Health |
| My health today | Summarizes today's steps, heart rate, and activity rings |
| Check my email | Fetches and summarizes recent Gmail messages |
| Habit check | Reports which habits are due or overdue today |
| Weather now | Fetches current weather for your location |
| Traffic to office | Estimates travel time to your saved office address |

:::tip
You can follow up with a free-form message after a chip result. The agent retains context within the current task.
:::

---

## Free-Form Tasks

Type or speak any request in the input bar. Examples:

- "What meetings do I have after 3 pm this Friday?"
- "Add a reminder to call the dentist tomorrow at 10 am"
- "Search the web for the best running routes in Montreal"
- "Summarize the PDF I attached and add action items to my notes"

The agent decides which tools to invoke based on the request. It may call several tools in sequence before responding.

---

## Available Tools

| Tool | What it accesses |
|---|---|
| `calendar` | Read and create EventKit events |
| `reminders` | Read and create EventKit reminders |
| `notes` | Read and create LucidPal notes |
| `habits` | Read habit definitions and today's completions |
| `contacts` | Look up contact names, numbers, and emails |
| `gmail` | Fetch and summarize Gmail messages |
| `health` | Read Apple Health data (sleep, steps, heart rate, activity) |
| `weather` | Current conditions for your location |
| `eta` | Travel time estimate to a saved destination |
| `web_search` | On-device web search |

---

## Voice Input in Agent Mode

Tap the **mic** button inside the Agent sheet to dictate your task. The same WhisperKit on-device transcription used in [Voice Input](./voice-input.md) applies here.

A **transcript confirmation bar** appears after transcription with a 3-second countdown. The task auto-submits when the timer reaches zero. Tap ✓ to submit immediately or ✕ to cancel.

### Continuous Voice Loop

:::note
Continuous voice loop is a **Pro** feature.
:::

With continuous loop enabled, the microphone reopens automatically after the agent finishes speaking its response (TTS). This lets you issue follow-up tasks hands-free without tapping the mic again.

---

## Spoken Responses (TTS)

:::note
Spoken responses are a **Pro** feature.
:::

When TTS is enabled, the agent reads its final answer aloud using on-device text-to-speech. A speaker icon in the response header indicates playback is active. Tap it to stop.

---

## Cancelling a Running Task

A **Cancel** button appears at the bottom of the sheet while the agent is executing. Tap it to interrupt the agentic loop immediately. Any tool calls already completed are not reversed.

---

## Permissions

Agent Mode uses the same system permissions as the individual tools it invokes. If a permission is missing, the agent will skip that tool and note it in the response.

| Tool | Permission required |
|---|---|
| Calendar / Reminders | Calendars & Reminders |
| Contacts | Contacts |
| Health | Health (read access per data type) |
| Microphone | Microphone (voice input only) |
| Location | Location (weather and ETA) |
| Gmail | Gmail OAuth — see [Gmail setup](./gmail.md) |

---

## Documents in Agent Mode

Attach PDFs, TXT, or RTF files to provide the agent with document context. See [Documents in Agent Mode](./document-summarization.md#in-agent-mode) for details.
