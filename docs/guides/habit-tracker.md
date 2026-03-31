---
sidebar_position: 8
---

# Habit Tracker

Build streaks, log progress, and get AI coaching — all without leaving LucidPal.

---

## Overview

LucidPal includes a full habit tracking system. Create habits, log completions, and view streaks and historical charts. The AI can log habits and answer questions about your progress directly from the chat.

---

## The Habit Dashboard

Tap the **Habits** tab (checkmark icon) in the navigation bar to open the dashboard. Each habit is shown as a card with:

- The habit name and icon
- Today's completion status
- Your current streak (consecutive days completed)

Tap any card to open the **Habit Detail View**, which shows a chart of your completion history over the past weeks.

---

## Creating a Habit

1. From the Habit Dashboard, tap **+** in the top-right corner.
2. Fill in the habit details:

| Field | Description |
|---|---|
| **Name** | What the habit is (e.g., "Meditate", "Read 20 pages") |
| **Frequency** | Daily, weekdays only, or custom days |
| **Reminder** | Optional time-based notification |

3. Tap **Create** — the habit appears on your dashboard immediately.

---

## Logging a Completion

**Manually:**
- From the dashboard, tap the circle on a habit card to mark it complete for today.
- To log with a note, tap the habit card, then tap **Log** on the detail screen and add optional notes.

**Via chat:**
> "I just meditated"

> "Log my reading habit for today"

> "Mark exercise done"

The AI confirms the log with a brief message.

---

## Asking the AI About Your Habits

> "How's my meditation streak going?"

> "Did I complete all my habits this week?"

> "What habit am I most consistent with?"

> "Create a new habit: drink 8 glasses of water daily"

The AI can both query your habit data and create new habits from the chat. It responds with a summary and, when relevant, shows your current streak.

---

## Log Habit via Siri

Use the **Log Habit** shortcut to record a completion hands-free:

> "Hey Siri, Log Habit in LucidPal"

Siri will ask which habit to log. Select it and confirm — LucidPal records the completion in the background.

You can also build Shortcuts automations — for example, automatically log a "Morning Routine" habit when you dismiss your alarm.

---

## Reading the Habit Chart

The detail view shows a bar chart (powered by Swift Charts) of your daily completions. Each bar represents one day:

- **Filled bar** — habit completed
- **Empty bar** — habit not completed (or not yet due)

The chart defaults to the last 30 days. Swipe left to see older data.

:::tip
Tap any bar in the chart to see the date and any note you logged for that day.
:::

---

## Streaks

A streak counts consecutive days you completed a habit. Missing a day resets the streak to zero.

| Streak indicator | Meaning |
|---|---|
| 🔥 flame icon | Active streak (3+ days) |
| Number | Current consecutive days |
| — | No active streak |

:::note
Streaks are calculated based on your local time zone. Logging at midnight edge cases count toward the correct calendar day.
:::

---

## Deleting a Habit

Open the Habit Detail View, scroll to the bottom, and tap **Delete Habit**. This permanently removes the habit and all its history.

:::warning
Deleting a habit also deletes all logged completions for that habit. This cannot be undone.
:::
