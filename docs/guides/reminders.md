---
sidebar_position: 11
---

# Reminders

Ask LucidPal to send you a notification at a specific time — without leaving the conversation.

---

## Overview

LucidPal can schedule iOS notifications on your behalf. Just ask in natural language and the AI picks the right time, sets the alert, and confirms it with a preview card. All reminders are delivered through Apple's notification system and stay entirely on-device.

---

## Asking the AI to Set a Reminder

Speak or type naturally — no special commands needed.

> "Remind me to call the pharmacy at 3 PM"

> "Don't let me forget to submit the report tomorrow morning"

> "Set a reminder for Friday at 9 AM — dentist appointment"

> "Ping me in 2 hours to check the oven"

The AI responds with a **Reminder Confirmation Card** inline in the chat. If the time is ambiguous (e.g. "tomorrow morning") the AI defaults to 9:00 AM in your local timezone.

### Reminder Confirmation Card

After the AI schedules a reminder, a confirmation card appears directly in the conversation thread. It contains:

| Element | Description |
|---------|-------------|
| **Bell icon** | Orange bell on the left side — indicates a reminder (not a calendar event) |
| **Title** | The reminder text, up to 2 lines |
| **Relative time** | Countdown to the trigger time (e.g. "in 2 hours") |
| **Scheduled time** | Exact clock time of the alert |
| **Notes** | Optional one-line note if extra context was provided |
| **Green checkmark** | Confirms the reminder was successfully scheduled |

The card has an orange border to visually distinguish it from calendar event cards and text responses.

:::note
Reminders are delivered as **local push notifications** by iOS — they do not create entries in the Apple Reminders app or your calendar.
:::

---

## Permissions

The first time you schedule a reminder, iOS asks for notification permission. Tap **Allow** to enable alerts.

If you previously denied permission:

1. Open **Settings → Notifications → LucidPal**
2. Toggle **Allow Notifications** on

---

## Limitations

| Limitation | Detail |
|------------|--------|
| Past dates | The AI will reject reminders set in the past |
| Repeating | Recurring reminders are not supported — set each one individually |
| Apple Reminders app | LucidPal does not read or write to the Apple Reminders app |
| Calendar events | Use the Calendar feature for timed events — reminders are notification-only |

---

## Tips

- You can set multiple reminders in a single session — just ask one at a time.
- Combine with a note: _"Save a note about my gym plan and remind me tonight at 8 PM to review it"_
- To cancel a scheduled reminder, go to **Settings → Notifications → LucidPal** and clear pending notifications, or simply dismiss the notification when it fires.
