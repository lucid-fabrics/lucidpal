---
sidebar_position: 12
---

# Habits

Track recurring behaviors — workouts, water intake, reading, and anything else you want to make consistent. LucidPal keeps a streak, visualizes progress, and lets the AI log entries from chat.

---

## Creating a Habit

1. Go to the **Habits** tab.
2. Tap **+** in the top-right corner.
3. Fill in the details and tap **Save**.

You can also create a habit by asking LucidPal in chat — for example, *"Create a daily push-ups habit"* — and the AI will set up the habit with a name, emoji, color, type, and frequency based on your request.

---

## Habit Settings

### Name & Icon

Tap the emoji button on the left of the name field to open the icon picker. The picker is organized into categories: Activity, Wellness, Food & Diet, Mind, Daily, and Creative. Tap any emoji to select it — the editor closes automatically.

You can also ask LucidPal in chat to create a habit with a specific emoji and color — the AI will configure it accordingly.

:::tip
Pick an emoji that's visually distinct so you can spot habits at a glance in the dashboard.
:::

### Accent Color

Scroll to **Accent Color** and tap any dot to pick the highlight color for this habit. The chosen color is applied to:

- The habit card on the dashboard
- Chart fills and bar colors in the detail view
- The accent highlights in the habit editor itself

| Color | Best for |
|-------|----------|
| Orange | Energy / fitness |
| Purple | Mind / meditation |
| Teal | Hydration / wellness |
| Green | Diet / nutrition |
| Indigo | Focus / learning |
| Pink | Relationships / self-care |

### Tracking Type

| Type | What it tracks | Example |
|------|---------------|---------|
| **Done** | Simple yes/no check-in | Meditated today |
| **Count** | A numeric quantity | Glasses of water |
| **Duration** | Time in minutes | Morning run |

### Frequency

| Option | Meaning |
|--------|---------|
| **Daily** | Resets every day; streak counts consecutive days |
| **Weekly** | One completion per week counts as done — streak is consecutive weeks |

### Daily Target

For **Count** and **Duration** habits, set a target using the `−` and `+` buttons. The target appears as a goal line in the detail chart and drives the streak calculation — a day counts as complete when the logged value meets or exceeds the target.

### Chart Style

Choose how progress looks in the habit detail view:

| Style | When to use |
|-------|------------|
| **Bar** | Daily discrete values — best for count or done/not habits |
| **Line** | Trend tracking — best for spotting patterns over weeks |
| **Area** | Emphasizes cumulative volume — best for duration habits |

You can change the chart style at any time by editing the habit — historical data is unaffected.

---

## Logging from the Dashboard

Tap any habit card to log a quick entry for today. For **Count** and **Duration** habits a small sheet appears so you can enter the value. For **Done** habits the card marks itself complete immediately.

---

## Habit Detail View

Tap a habit's title (or long-press the card) to open the full detail screen.

- **Chart** — shows the last 14, 30, or 90 days in the style you chose
- **Streak** — current consecutive days streak (or consecutive weeks for weekly habits)
- **Stats** — average, best, and total for the selected period
- **Log history** — all individual entries with optional notes

---

## AI Logging from Chat

You can manage habits directly from the chat without opening the Habits tab.

| What you say | What happens |
|--------------|-------------|
| "Log my run for today" | Records an entry for the matching habit |
| "I did 30 minutes of yoga" | Logs 30 against a duration habit |
| "Mark my water habit done" | Logs 1 for a done/not habit |
| "How is my reading streak?" | Returns a 7-day summary and current streak |
| "Create a daily push-ups habit" | Creates a count habit named "Push-ups" |
| "Create a weekly meditation habit with a purple theme" | Creates a weekly habit with specified settings |

When creating a habit via chat, the AI can set: **name**, **emoji**, **color** (accent hex), **type** (done/count/duration), **frequency** (daily/weekly), and **target** (for count/duration types).

:::note
AI habit matching is fuzzy — "my run" will match a habit named "Morning Run". Ask the AI to **query** a habit by name first if you're unsure of the exact match.
:::

---

## Editing a Habit

1. Open the habit detail screen.
2. Tap the **Edit** button (pencil icon) in the toolbar.
3. Change any field — name, icon, color, type, frequency, target, or chart style.
4. Tap **Save**.

All logged entries are preserved when you edit a habit.

---

## Archiving a Habit

Archive habits you no longer track — your history is preserved but the habit disappears from the active dashboard.

1. Open the habit detail screen.
2. Tap the menu (**···**) in the top-right corner.
3. Select **Archive**.

To restore: go to **Settings → Data & Privacy → Archived Habits**, open the habit, and tap **Restore**.

---

## Logging via Siri

You can log a habit entry without opening the app:

> "Hey Siri, log my workout in LucidPal"

The AI matches your spoken habit name and records today's entry. Works in the background — no app open required.

---

## Limits

- Up to **100 habits** can be active at once
- Entries are stored in monthly JSON files (`lucidpal_entries_YYYY-MM.json`) cached in memory
- Oldest entries are loaded from disk on demand for the current and previous month
