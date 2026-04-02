---
sidebar_position: 14
---

# Widgets & Notifications

Keep your schedule visible at a glance with Home Screen widgets and smart pre-event alerts.

---

## Home Screen Widgets

LucidPal provides three widget sizes. Add them via the iOS widget picker (long-press the Home Screen → **+** → LucidPal).

### Small Widget

Shows your **habit progress ring** (habits done / total today) with the percentage filled in the centre, plus the name and day-count of your **top active streak** below it.

**Fallback priority (left to right):**
1. Habit progress ring + top streak — default when habits are configured
2. Next calendar event (title + countdown) — shown when all habits are already done for the day
3. "Free today" — shown when no habits are configured

### Medium Widget

Split into two panels:

| Panel | Content |
|-------|---------|
| Left | Next calendar event — title, start time, and countdown |
| Right | Habit progress (done/total) → pinned note title → free time slots (shown in priority order; first available content wins) |

### Large Widget

Three stacked sections:

1. **Today's Events** — up to 3 upcoming events (title + time range + countdown badge if within 1 hour)
2. **Habit Progress** — a progress bar (habits done / total) and the top streak name + days as a capsule
3. **Pinned Note** — the title of your most recently pinned note, if any

### App Group Data Flow

Habit and note data reaches the widget through a shared JSON snapshot, not direct file access:

1. The main app writes `lucidpal_widget_snapshot.json` to the **`group.app.lucidpal`** App Group container after every habit log and note save.
2. The widget extension reads the snapshot at refresh time via `WidgetSnapshotReader.read()`.

The `WidgetSnapshot` model contains:

| Field | Type | Description |
|-------|------|-------------|
| `writtenAt` | `Date` | Timestamp of the last write |
| `habitsToday` | `Int` | Habits completed today |
| `habitsTotal` | `Int` | Total active habits |
| `topStreakName` | `String?` | Name of the habit with the longest active streak |
| `topStreakDays` | `Int` | Day count of that streak |
| `pinnedNote` | `String?` | Title of the most recently pinned note |

### Timeline Refresh Policy

The widget timeline refreshes on `.after(eventEnd)` for each scheduled event end, or every **15 minutes** as a fallback. The snapshot is read fresh on each reload.

When an event is coming up, the widget schedules targeted entries:

- **Event − 30 min** — relevance score boosted to surface the widget in Smart Stack.
- **Event start** — maximum relevance for the full duration of the event.
- **Event end** — relevance drops back to idle; a fresh timeline fetch is triggered.

### Empty States

| Condition | Small | Medium | Large |
|-----------|-------|--------|-------|
| No habits configured | "Free today / Tap to ask anything" | Next event + free slots only | Events only |
| All habits done | Next event or "Free today" | Next event + first available right-panel content | Full layout, progress bar shows 100% |
| No events today | Habit ring + top streak | Habit ring on right | Habit section only, events section hidden |

### Tapping the Widget

Every tap opens LucidPal and starts a **new chat** via the `lucidpal://newchat` deep link.

### Data Source

Calendar data is read **directly via EventKit**. Habit and note data is read from the **`group.app.lucidpal`** App Group container. Both calendar access and the App Group entitlement must be configured for all widget content to display.

:::note
The widget extension queries calendar events from **now through end of today** for the day view, and **now through 7 days ahead** to find the next upcoming event.
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
