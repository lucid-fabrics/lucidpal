---
sidebar_position: 8
---

# Habit Tracker

Build streaks, log progress, and get AI coaching — all without leaving LucidPal.

---

## Overview

LucidPal includes a full habit tracking system. Create habits, log completions, and view streaks and historical charts. The AI can log habits and answer questions about your progress directly from the chat.

---

## Voice Logging

Speak naturally in the chat to log a habit — no tapping required.

> "I just meditated for 10 minutes"

> "I ran 5km"

> "Did my cold shower this morning"

LucidPal extracts the habit name and value from your sentence and logs the entry immediately. The AI confirms with an inline card showing the habit emoji, name, and current streak. If no matching habit is found, it offers to create one.

---

## Streak Heroes

At the top of the Habits tab, up to **three Streak Hero cards** highlight your longest active streaks. Each card shows:

- The habit emoji and name
- The current streak length (e.g. "12 days")
- A flame icon indicating an active run

Cards are ranked by streak length (longest first) and only appear for habits with a streak greater than zero. Archived habits are excluded. If you have no active streaks, this section is hidden.

---

## The Habit Dashboard

Tap the **Habits** tab (checkmark icon) in the navigation bar to open the dashboard. At the top, a **progress bar** shows how many habits you've completed today (e.g. "3 of 5 done today").

Each habit card shows:

- The habit name and icon
- Today's completion status
- Your current streak (consecutive days completed)
- A **`+` button** in the bottom-right corner for quick-logging (see [Logging a Completion](#logging-a-completion))

Tap any card to open the **Habit Detail View**, which shows stats and a chart of your completion history.

Below each habit card, a row of **seven dots** shows your completion status for the past 7 days (today on the right). A filled dot means completed; an empty dot means missed or not yet logged. This gives you a quick visual of your recent consistency without opening the detail view.

If you have no habits yet, the dashboard shows **template cards** (Meditate, Exercise, Drink Water, Read, Sleep 8hrs, Journal, No Sugar, Cold Shower). Tap any template to open the creation sheet pre-filled with that habit's name and settings.

---

## Weekly Trends

Every habit card shows a row of **seven completion dots** directly below the habit name — one dot per day, starting 6 days ago and ending today. A filled dot means the habit was completed on that day; an empty dot means it was not.

This trend strip lets you spot patterns at a glance:
- Three empty dots in a row → a mid-week slump to address
- Seven filled dots → a perfect week
- Today's dot is filled as soon as you log the habit

Weekly trend dots are visible in both the dashboard grid view and the Habit Detail View.

---

## Starting from a Template

When the dashboard is empty, template cards give you a one-tap starting point. Tap any template card (Meditate, Exercise, Drink Water, Read, Sleep 8hrs, Journal, No Sugar, Cold Shower) to open the creation sheet with the habit name and type pre-filled. Adjust anything you like, then tap **Create**.

Templates are only shown when your habit list is **empty**. Once you have at least one habit (active or archived), the template cards are hidden and the **+** button is the only way to create new habits.

---

## Creating a Habit

1. From the Habit Dashboard, tap **+** in the top-right corner.
2. Fill in the habit details:

| Field | Description |
|---|---|
| **Emoji** | Single emoji displayed on the card (tap the emoji field to change it) |
| **Name** | What the habit is (e.g., "Meditate", "Read 20 pages") |
| **Unit** | **Done/Not** (boolean), **Count** (numeric reps), or **Duration** (minutes) |
| **Frequency** | **Daily** or **Weekly** |
| **Daily Target** | Target value for count/duration habits (e.g., 30 min, 10 reps). Not shown for Done/Not habits. |

3. Tap **Save** — the habit appears on your dashboard immediately.

---

## Logging a Completion

**Manually:**

Tap the **`+` button** on a habit card:

- **Boolean habit** (done / not done) — logs immediately.
- **Count or duration habit** — opens the Log Habit sheet, where you use a **stepper** to set the value (count steps by 1 up to 9999; duration steps by 5 minutes up to 600 minutes). You can also add an optional note before tapping **Log**.

If the habit is already logged today, the `+` is replaced by a checkmark.

:::note
Logging a habit a second time on the same day **replaces** the earlier entry — it does not add to it. The most recent log value is kept. This applies to both manual logs and AI-triggered logs.
:::

Alternatively, tap the habit card to open the detail view and use the **Log** button there — useful if you want to review history at the same time.

**Via chat:**
> "I just meditated"

> "Log my reading habit for today"

> "Mark exercise done"

The AI confirms the log with a brief inline card showing the habit emoji, name, action label (Logged / Created / Stats), current streak, and the logged value.

The AI uses three actions internally:

| Action | JSON format | What it does |
|--------|-------------|--------------|
| `log` | `{"action":"log","habit":"name","value":1}` | Records an entry; `value` defaults to 1 |
| `create` | `{"action":"create","name":"name","unit":"boolean","frequency":"daily","emoji":"🎯"}` | Creates a new habit definition |
| `query` | `{"action":"query","habit":"name"}` | Returns a 7-day summary and current streak |

Valid units: `boolean` (done/not done), `count` (numeric reps), `duration` (minutes).
Valid frequencies: `daily`, `weekly`.

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

Use the **segmented picker** above the chart to choose your time window: **14d**, **30d**, or **90d**.

:::tip
Tap any bar in the chart to see the date and any note you logged for that day.
:::

---

## Streaks

A streak counts consecutive days you completed a habit. Missing a day resets the streak to zero.

| Streak indicator | Meaning |
|---|---|
| 🔥 flame icon | Active streak |
| Number | Current consecutive days |
| — | No active streak |

:::note
Streaks are calculated based on your local time zone. Logging at midnight edge cases count toward the correct calendar day.
:::

### Stats Row

The Habit Detail View shows a row of five stats:

| Stat | What it shows |
|------|--------------|
| 🔥 Streak | Current consecutive-day streak |
| 🏆 Best | Your all-time best streak |
| 📅 This Month | Completions in the current calendar month |
| 📊 30d Rate | Completion percentage over the last 30 days |
| Σ Total | All-time completion count |

### Milestone Badges

When your best streak reaches a milestone, a badge appears in the detail view:

| Badge | Milestone |
|-------|-----------|
| 🔥 7-Day | Best streak ≥ 7 days |
| ⚡️ 14-Day | Best streak ≥ 14 days |
| 🏆 30-Day | Best streak ≥ 30 days |
| 🌟 100-Day | Best streak ≥ 100 days |

When you hit one of these milestones by quick-logging a boolean habit, a **celebration overlay** animates on screen to mark the achievement.

---

## Deleting a Habit

Open the Habit Detail View, scroll to the bottom, and tap **Delete Habit**. This permanently removes the habit and all its history.

:::warning
Deleting a habit also deletes all logged completions for that habit. This cannot be undone.
:::