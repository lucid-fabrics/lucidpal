---
sidebar_position: 15
---

# Daily Briefing

A personalised morning (or evening) snapshot shown once per day when you open LucidPal.

---

## Overview

The Daily Briefing is a card that greets you on your first cold open of the day. It summarises where you stand — habits, streaks, notes, and calendar — so you can orient quickly without navigating to multiple tabs.

---

## What It Shows

| Item | Example |
|------|---------|
| Habit completion count | "2 of 5 habits done today" |
| Top active streak | "🔥 Meditate — 12 days" |
| Pinned note count | "3 pinned notes" |
| Most recent note title | "Project proposal draft" |
| Today's calendar event count | "4 events today" |

---

## When It Appears

The briefing appears **once per calendar day** on a **cold open** — the first time you launch LucidPal since midnight. It does not reappear on subsequent session switches within the same app lifecycle (e.g. returning to the app after switching to another app and back).

---

## Evening Nudge Mode

After **6 PM**, if you have habits that have not been logged yet today, the briefing switches to evening nudge mode and leads with:

> "X habits still unlogged today"

This prompts you to close out the day's habits during your evening review without having to check the Habits tab manually.

---

## How to Dismiss

| Action | Effect |
|--------|--------|
| Tap the **×** button | Closes the briefing immediately |
| Tap the **microphone** | Closes the briefing and activates voice input |
| Start typing | Closes the briefing and focuses the chat input |

---

## Log Shortcut

The briefing includes a **Log** button that opens a new chat pre-seeded with:

> "Log my habits for today"

Tap it to jump straight into logging all of today's habits via conversation — no need to switch to the Habits tab or tap individual habit cards.

---

## Does Not Appear When

- You have already seen the briefing today (same calendar day, any session).
- You switch back to LucidPal mid-session (not a cold open).
- It is not yet past midnight (the briefing is anchored to the current calendar day, not a 24-hour rolling window).

<details>
<summary>For developers</summary>

See [architecture/system-prompt](../architecture/system-prompt#daily-briefing-context) for how `DailyBriefingBuilder` assembles the briefing from `HabitStore`, `NotesStore`, and the calendar, and for the `isEveningNudge` flag logic.

</details>
