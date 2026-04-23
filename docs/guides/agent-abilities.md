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

These 10 abilities are installed by default and appear in the Abilities drawer.

| Ability | What it does |
|---------|-------------|
| **Briefing** | Pulls calendar, overnight health, weather, and unread email. Returns 3 bullets: what you must not miss, any risk or conflict, and whether your body is ready for a demanding day. |
| **Calendar** | Analyzes today's schedule — most important event, back-to-back conflicts, and best slot for focused work. Not just a list. |
| **Health** | Compares today's steps, heart rate, and HRV to your 7-day average. Returns one verdict (recovered / neutral / drained) and one action. |
| **Email** | Triages unread Gmail — skips newsletters and automations, ranks emails that need a human reply by urgency. |
| **Weather** | Translates today's forecast into decisions: jacket or umbrella, commute impact, any alerts. |
| **Habits** | Shows which habits are done and which aren't, then prioritizes the incomplete ones by what you can still realistically finish today. |
| **Plan Day** | Builds a concrete time-blocked schedule across morning, afternoon, and evening — with risk flags where your day is overloaded. |
| **Traffic** | Checks live traffic to your saved destination and tells you whether to leave now or wait, plus any faster route. |
| **Notes** | Surfaces the 3 most actionable items from your last 7 days of notes — ideas you didn't follow up on, and anything relevant to today's events. |
| **Reminder** | Asks what you need reminding about and when, then sets it immediately without back-and-forth. |

---

## Template Library

Beyond the defaults, you can add abilities from the template library. Swipe the drawer all the way up, long-press any ability, tap **Edit Dock**, then **Add** to browse templates organized by category.

### Morning

| Template | What it does |
|----------|-------------|
| **Briefing** | Same as the default — synthesized morning briefing. |
| **Weather** | Decision-first forecast. |
| **Traffic** | Leave-now recommendation. |
| **Sleep** | Last night's duration, deep sleep %, and HRV vs. 7-day average — one recovery verdict. |
| **Motivate** | Checks your habits streak and today's calendar, then delivers one personalized sentence to start your day (not a generic quote). |

### Productivity

| Template | What it does |
|----------|-------------|
| **Calendar** | Calendar intelligence — insights, not a raw list. |
| **Plan Day** | Time-blocked schedule with risk flags. |
| **Notes** | Forgotten tasks and calendar-linked notes. |
| **Reminder** | Ask once, set immediately. |
| **Free Time** | Ranks your open calendar gaps by quality and tells you which block to protect for deep work. |
| **Focus** | Cross-references your next 2 events, incomplete habits, and HRV — delivers one sentence on what to do right now. |
| **Prep** | Meeting prep: scans recent emails from attendees, your notes on the topic, and last interaction — gives 3 talking points. |

### Health

| Template | What it does |
|----------|-------------|
| **Health** | Daily metrics vs. 7-day average with one action. |
| **Habits** | Realistic completion priority given your calendar. |
| **Workout** | Recovery-based workout recommendation (type, duration, best time slot). |
| **Hydrate** | Activity-adjusted hydration goal with a noon check-in reminder. |
| **Stress** | HRV trend vs. baseline with a context-aware de-stress technique if needed. |

### Communication

| Template | What it does |
|----------|-------------|
| **Email** | Ranked email triage — only emails that need a reply. |
| **Inbox** | 48-hour inbox grouped into: needs reply, informational, safe to archive. |
| **Reply** | Drafts a send-ready reply to the most urgent unread email. |
| **Contacts** | Looks up name, phone, email, and recent email threads for anyone you mention. |

### Evening

| Template | What it does |
|----------|-------------|
| **Review** | 3-line honest day review using actual numbers — accomplishments, misses, one pattern. |
| **Tomorrow** | Pulls tomorrow's calendar and deadline emails — gives the most important pre-bed action and your ideal wake time. |
| **Wind Down** | 20-minute wind-down plan with a screen-off time based on your sleep target. |
| **Gratitude** | Finds 3 specific highlights from today's data and writes a 3-sentence gratitude entry. |

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
