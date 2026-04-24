---
sidebar_position: 8
---

# Agent & Abilities

The Agent screen is LucidPal's hands-free assistant — it listens, queries your data sources, and delivers a synthesized answer without you having to type anything. **Abilities** are one-tap shortcuts that trigger pre-built tasks the Agent knows how to execute.

---

## The Agent Screen

Tap the **Agent** tab (the orb icon at the bottom of the screen) to open the Agent screen. You'll see:

- A **pearl orb** in the centre, surrounded by orbiting icons — tap it to speak your request.
- An **Abilities drawer** at the bottom — swipe it up or tap an ability to run a task instantly.
- A **keyboard button** (top right) to type instead of speaking.
- A **history button** (top left) to review past agent sessions.

### Speaking to the Agent

1. Tap the orb. It expands and pulses — start speaking.
2. A live audio meter animates in real time as you speak, giving you visual confirmation that your voice is being captured.
3. A live transcript appears. You have 3 seconds to review it, or tap to submit immediately.
4. The Agent queries your connected data sources in real time (you'll see "Checking your calendar…", "Reading emails…", etc.).
5. The answer appears in a sheet with structured cards or plain text. Pull it down to dismiss.

:::note
The Agent requires **microphone access** to listen. If permission hasn't been granted, you'll see a prompt the first time you tap the orb. You can change this anytime in **Settings → Privacy → Microphone**.
:::

### Troubleshooting Voice Input

If recording doesn't work, the Agent shows a clear message:

| Message | What it means | What to do |
|---------|---------------|------------|
| *Microphone permission not granted.* | LucidPal doesn't have mic access. | Settings → Privacy → Microphone → enable LucidPal. |
| *Already recording.* | A previous session didn't fully reset. | Wait a moment and try again. |
| *Still processing your previous message.* | Whisper is still transcribing. | Wait for the current task to finish. |
| *Nothing was captured. Tap the orb and speak.* | No audio was detected. | Tap the orb and speak clearly at a normal pace. |

---

## What Abilities Are

Abilities are pre-configured tasks. Each ability is:

- A **label and icon** identifying what it does.
- A **prompt** — a precise instruction the Agent follows when you tap it.
- An optional **plan key** — a structured workflow that queries specific data sources in the right order before synthesizing.

The Agent doesn't just run a search — it cross-references multiple data sources, compares to your baselines, and returns a verdict with an action recommendation.

---

## Default Abilities

Five built-in abilities ship with LucidPal:

| Ability | What it does |
|---------|-------------|
| **Morning Briefing** | Pulls health, weather, today's calendar, and recent emails. Returns a concise briefing: energy level, weather decisions, top events, and urgent emails. |
| **Meeting Prep** | Finds the next meeting, pulls attendee contacts, searches relevant emails, and does a web search for background context. Returns talking points. |
| **Day Planner** | Checks health and today's calendar, finds free slots, reviews pending habits. Returns a time-blocked schedule slotted around existing commitments. |
| **Email Triage** | Fetches recent emails via Gmail, skips newsletters and automations, returns a categorized summary with urgent items first. |
| **Habit Coach** | Queries all habits and today's completion status, cross-references with health metrics. Returns an assessment with one insight correlating habits and recovery. |

---

## Template Library

The Abilities drawer can be expanded to reveal additional templates. Swipe the drawer all the way up, long-press any ability, tap **Edit Dock**, then **Add** to browse. Templates are organized by category.

### Morning

| Template | What it does |
|----------|-------------|
| **Briefing** | Concise morning briefing covering health, weather, calendar, and email. |
| **Weather** | Decision-first forecast — jacket or umbrella, commute impact, alerts. |
| **Sleep** | Last night's duration, deep sleep %, and HRV vs. 7-day average with a recovery verdict. |

### Productivity

| Template | What it does |
|----------|-------------|
| **Calendar** | Calendar intelligence — most important event, conflicts, best focus slot. |
| **Day Planner** | Time-blocked schedule with risk flags for overloaded periods. |
| **Notes** | Surfaces the 3 most actionable items from recent notes. |
| **Reminder** | Ask once, set immediately. |
| **Free Time** | Ranks open calendar gaps by quality and tells you which block to protect. |

### Health

| Template | What it does |
|----------|-------------|
| **Health** | Today's steps, HRV, heart rate vs. 7-day average — one verdict and one action. |
| **Habits** | Incomplete habits prioritized by what's realistic to finish today given your calendar. |

### Communication

| Template | What it does |
|----------|-------------|
| **Email Triage** | Ranked Gmail triage — only emails that need a human reply. |
| **Contacts** | Looks up name, phone, email for anyone you mention by name. |

---

## Customizing Your Abilities

### Reordering

Long-press an ability and drag it to a new position in the drawer.

### Editing a prompt

Long-press any ability → **Edit Ability** to change the label, icon, color, or prompt. The Agent will use your edited prompt exactly — write it the same way you'd speak to a smart colleague.

### Removing an ability

Long-press an ability → **Delete**, or enter jiggle mode (long-press → **Edit Dock**) and tap the red **−** badge.

### Adding from the template library

Enter jiggle mode → tap **Add** → browse by category → tap any template to install it.

### Sharing a custom ability

Long-press any ability → **Share** to export it. The recipient can tap the exported file to install it directly in their LucidPal.

---

## Writing Your Own Ability Prompts

You can create entirely custom abilities. Tips for prompts that actually work:

| What to do | Why |
|------------|-----|
| **Name the data sources** | "Check my calendar and HRV" is better than "check how I'm doing." |
| **Ask for a verdict, not a list** | "Tell me if I'm recovered or drained" beats "show me my HRV." |
| **Specify output format** | "Three bullets" or "one sentence" constrains the answer to what you need. |
| **End with an action** | "Then tell me what I should do next" makes every answer useful. |
| **Use comparison** | "Compare to my 7-day average" gives numbers meaning. |

**Example of a weak prompt:**
> "How's my health today?"

**Example of a strong prompt:**
> "Pull today's steps and HRV. Compare to my 7-day average. Tell me in one sentence if I'm recovered or behind — then suggest one thing I should or shouldn't do today based on the numbers."

---

## Answer Cards

When an ability finishes, the answer appears in a sheet. Pull it down to dismiss, or swipe up to expand to full height. Some abilities return **structured cards**:

| Card type | When it appears |
|-----------|----------------|
| **Morning Briefing** | Briefing ability — summary tiles for health, weather, calendar, and email. |
| **Calendar** | Calendar ability — event list with time and title. |
| **Health** | Health ability — metric grid with trend indicators. |
| **Plain text** | Any other prompt — formatted markdown with copy button. |

The sheet echoes your original request at the top so the answer is self-contained without any surrounding context.

---

## Ability History

Tap the **clock** icon (top left) to see a history of all past agent sessions — what you asked, what tools the Agent used, and what it returned.

---

## Connectivity and Permissions

| Data source | Required permission |
|-------------|-------------------|
| Calendar | Calendar access (read) |
| Health | Health access (steps, HRV, sleep, heart rate) |
| Email | Gmail authorization |
| Weather | Location access (for local forecast) |
| Traffic | Location access |
| Notes | Notes access |
| Contacts | Contacts access |
| Reminders | Reminders access |

If a permission is missing, the Agent will tell you which one it needs and what to enable in Settings → Privacy.

:::tip
The **Briefing** ability is the fastest way to see if everything is working — it touches health, calendar, weather, and email in one shot.
:::

:::note
Abilities that use cloud synthesis (email, Gmail reply) require an active Starter or higher subscription. On-device abilities (calendar, health, habits, notes, reminders) work with a local model and no subscription.
:::
