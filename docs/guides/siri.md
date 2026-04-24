---
sidebar_position: 2
---

# Siri Shortcuts

Eleven built-in Siri intents let you manage your calendar, notes, contacts, habits, and reminders — without opening the app.

## Available Shortcuts

| Shortcut | Example phrase | What it does |
|----------|---------------|---------------|
| **Talk to LucidPal** | "Hey Siri, Talk to LucidPal" | Opens the app and starts voice input immediately |
| **Ask LucidPal** | "Ask LucidPal what's on my schedule" | Opens the app and sends your question |
| **Check My Calendar** | "Check my LucidPal calendar" | Shows today's events |
| **Add Calendar Event** | "Add dentist to LucidPal" | Starts an event creation |
| **Find Free Time** | "Find free time in LucidPal" | Finds a free 1-hour slot today |
| **Delete Calendar Event** | "Delete event in LucidPal" | Searches for an event, shows preview, deletes after confirmation |
| **Undo Last Action** | "Undo my last LucidPal action" | Reverses the most recent calendar action (create, delete, update, or reschedule) — whether done via Siri or inside the app |
| **Save Note** | "Save note to LucidPal" | Saves a titled note — runs without opening the app |
| **Find Contact** | "Find contact in LucidPal" | Looks up a contact's phone and email — runs without opening the app |
| **Log Habit** | "Log habit in LucidPal" | Records a habit entry — runs without opening the app |
| **Set Reminder** | "Set reminder in LucidPal" | Schedules a local notification — runs without opening the app |

---

## Background Shortcuts

Five intents run entirely in the background — they never open LucidPal:

| Intent | What it does |
|--------|-------------|
| Save Note | Saves a titled note — runs without opening the app |
| Find Contact | Looks up a contact's phone and email — runs without opening the app |
| Log Habit | Records a habit entry — runs without opening the app |
| Set Reminder | Schedules a local notification — runs without opening the app |
| Delete Calendar Event | Searches for an event and deletes it after confirmation — runs without opening the app |

---

## Setting Up Siri Shortcuts

On iOS 16.4 and later, shortcuts are suggested automatically after you use LucidPal a few times. On earlier versions:

1. **Open the Shortcuts app** — find it on your Home Screen or search in Spotlight.
2. **Tap the + button** — create a new shortcut.
3. **Search for LucidPal** — all LucidPal intents appear in the app actions list.
4. **Add a Siri phrase** — tap **Add to Siri** and record your preferred trigger phrase.

---

## How It Works

Because LucidPal runs AI on-device, Siri can't process your request directly. Instead:

1. You say your phrase — Siri confirms with a brief spoken reply (e.g. _"Let me check your calendar."_)
2. LucidPal opens in the foreground.
3. Your request is automatically sent to the AI — no typing required.
4. The response appears in a new conversation.

---

## Examples

**Starting a voice conversation:**

> "Hey Siri, Talk to LucidPal"

LucidPal opens and immediately starts listening. Speak your request naturally — no need to tap anything.

**Checking your day:**

> "Hey Siri, check my LucidPal calendar"

Siri replies: _"Let me check your calendar."_ LucidPal opens and immediately shows today's events.

**Adding an event by voice:**

> "Hey Siri, add dentist to LucidPal"

Siri asks: _"What would you like to add to your calendar?"_
You say: _"Dentist appointment Friday at 10am"_
LucidPal opens and shows a preview card ready to confirm.

**Finding a meeting slot:**

> "Hey Siri, find free time in LucidPal"

LucidPal opens and searches for the next free 1-hour slot today.

**Deleting an event by voice:**

> "Hey Siri, delete event in LucidPal"

Siri replies: _"Which event would you like to delete?"_
You say: _"Team standup tomorrow"_
LucidPal shows a preview card of the matching event and asks you to confirm before deleting.

**Undoing your last action:**

> "Hey Siri, undo my last LucidPal action"

LucidPal looks at what you did most recently — inside the app or via Siri — and reverses it:

| Last action | What happens |
|-------------|-------------|
| Delete event | Restores the deleted event to your calendar |
| Create event | Deletes the newly created event |
| Update / reschedule event | Undo not yet supported for edits — LucidPal tells you this |
| Nothing recorded | LucidPal says there is nothing to undo |

---

## Event Preview Card

When a Siri shortcut returns a calendar event (e.g. **Add Calendar Event**, **Delete Calendar Event**, **Check My Calendar**), LucidPal displays an **Event Preview Card** in the conversation thread.

| Element | Description |
|---------|-------------|
| **Date badge** | Abbreviated month (e.g. "APR") with day number — red header for active, grey for deleted |
| **Title** | Event name, truncated to one line |
| **Time range** | Start and end time, or "All day" |
| **Calendar name** | The calendar the event belongs to |
| **Deleted state** | Title struck-through, grey badge, reduced opacity, green checkmark confirms deletion |

---

## Tips

- Shortcuts work on iPhone, iPad, HomePod, AirPods, Apple Watch, and CarPlay.
- You can customize the trigger phrase to anything you like in the Shortcuts app.
- The **Add Calendar Event** shortcut lets you dictate the full event detail in one sentence.
- The **Delete Calendar Event** shortcut also responds to _"Delete a LucidPal event"_, _"Remove event from LucidPal"_, and _"Delete my LucidPal event"_.
- The **Undo Last Action** shortcut also responds to _"Undo what I just did in LucidPal"_, _"Undo last LucidPal change"_, _"Restore deleted event in LucidPal"_, and _"Undo LucidPal deletion"_.
- **Set Reminder** creates a local notification. For conversational reminders via AI, ask LucidPal directly in chat — it can set reminders with natural language understanding.