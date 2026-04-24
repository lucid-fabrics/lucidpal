---
sidebar_position: 14
---

# Widgets & Notifications

Keep your schedule visible at a glance with Home Screen widgets and smart pre-event alerts.

---

## Home Screen Widgets

LucidPal provides three widget sizes. Add them via the iOS widget picker (long-press the Home Screen → **+** → LucidPal).

| Size | What it shows |
|------|---------------|
| **Small** | Countdown to next event, event title, and start time. Shows "Free today" with a chat prompt when no events remain. |
| **Medium** | Left panel: next event title, start time, countdown. Right panel: up to 3 free time slots today (duration + start time). Shows "No gaps today" when the work day is fully booked. |
| **Large** | Full-day header with today's date, up to 4 remaining events (title + time range + countdown badge if within 1 hour), overflow count, and an "Ask your AI" CTA. Shows "Free day — tap to plan it" when the calendar is empty. |

:::note
Smart widget refresh (timeline entries, Smart Stack surfacing) requires a **Pro or Ultimate** subscription. Free and Starter plans show the widget but it does not receive targeted refresh entries. Live Activity in the Dynamic Island also requires Pro+.
:::

:::tip
Use the **Medium** widget on your most-visited Home Screen page for an instant overview of what's next and when you're free.
:::

### What counts as a free slot?

Free slots are gaps in your calendar **between 9 AM and 5 PM** that are at least **15 minutes** long. All-day events are excluded from the free-slot calculation. The widget surfaces up to 3 slots in the Medium size.

### Timeline refresh policy

The widget timeline refreshes **every 15 minutes** when no upcoming event is found. When an event is coming up, the widget schedules targeted entries:

- **Now** — low relevance unless the event starts within 30 minutes.
- **Event − 30 min** — relevance score boosted to surface the widget in Smart Stack.
- **Event start** — maximum relevance for the full duration of the event.
- **Event end** — relevance drops back to idle; a fresh timeline fetch is triggered.

### Empty states

| Condition | Small | Medium | Large |
|-----------|-------|--------|-------|
| No events today or in next 7 days | "Free today / Tap to ask anything" | "Free today / Ask anything" + no free-slot panel | "Free day — tap to plan it" |
| No free gaps in 9–5 window | — | "No gaps today" | — |

### Tapping the widget

Every tap (on any widget element) opens LucidPal and starts a **new chat** via the `lucidpal://newchat` deep link. There is no event-specific deep link — tapping an individual event row in the Large widget also opens a new chat.

### Data source

The widget reads your calendar **directly via EventKit** — it does not share data through an App Group with the main app. Calendar access (`fullAccess` or the legacy `authorized` status) must be granted for any data to appear. If access is denied, all three widgets show their empty state.

:::note
The widget extension reads only from the default EventKit store. It queries events from **now through end of today** for the day view, and **now through 7 days ahead** to find the next upcoming event.
:::

---

## Pre-Event Smart Notifications

LucidPal sends a local notification **10 minutes before** each upcoming calendar event.

Tapping the notification opens LucidPal so you can start a preparation chat for that event.

Notifications are scheduled each time the app becomes active, covering events in the **next 24 hours**. All-day events are excluded.

### Requirements

- Grant LucidPal **notification permission** (Settings → Notifications → LucidPal).
- LucidPal must have calendar access to read upcoming events.

:::note
Notifications are scheduled locally on your device. They do not require an internet connection and LucidPal never sends your calendar data to a remote server.
:::

### Adjusting or disabling

Toggle pre-event reminders on or off in **LucidPal → Settings → Notifications**. You can also disable them in **iOS Settings → Notifications → LucidPal**, or revoke calendar access in **iOS Settings → Privacy & Security → Calendars**.
