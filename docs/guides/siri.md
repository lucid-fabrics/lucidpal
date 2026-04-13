---
sidebar_position: 2
---

# Siri Shortcuts

Manage your calendar hands-free using Siri and LucidPal.

LucidPal includes ten built-in Siri shortcuts. You can trigger them with your voice without ever opening the app.

## Available Shortcuts

| Shortcut              | Example phrase                       | What it does                                                                                                       |
| --------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| Talk to LucidPal      | "Hey Siri, Talk to LucidPal"         | Opens the app and starts voice input immediately                                                                  |
| Ask LucidPal          | "Ask LucidPal what's on my schedule" | Opens the app and sends your question                                                                              |
| Check My Calendar     | "Check my LucidPal calendar"         | Shows today's events                                                                                               |
| Add Calendar Event    | "Add dentist to LucidPal"            | Starts an event creation                                                                                           |
| Find Free Time        | "Find free time in LucidPal"         | Finds a free 1-hour slot today                                                                                     |
| Delete Calendar Event | "Delete event in LucidPal"           | Searches for an event, shows a preview, and deletes it after confirmation                                          |
| Undo Last Action      | "Undo my last LucidPal action"       | Reverses the most recent calendar action (create, delete, or update) — whether triggered by Siri or inside the app |
| Save Note             | "Save note to LucidPal"              | Saves a titled note to LucidPal's notes store — runs without opening the app                                       |
| Find Contact          | "Find contact in LucidPal"           | Looks up a contact's phone number and email by name — runs without opening the app                                 |
| Log Habit             | "Log habit in LucidPal"              | Records a habit entry to LucidPal's habit store — runs without opening the app                                     |
| Set Reminder          | "Set reminder in LucidPal"           | Schedules a local notification reminder — runs without opening the app                                             |

---

## Background Shortcuts (Shortcuts App)

Four additional intents run entirely in the background — they never open LucidPal. These appear in **Settings → Shortcuts** and in the Shortcuts app under LucidPal actions.

| Intent                       | What it does                                                                   |
| ---------------------------- | ------------------------------------------------------------------------------ |
| Ask LucidPal (Background)    | Saves your question and opens LucidPal with it pre-filled                      |
| Create Event                 | Creates a calendar event (title, start time, duration, optional location/notes) |
| Check Next Meeting           | Returns the title, time, and location of your next calendar event              |
| Find Free Time               | Returns the first available time slot on a given date for a given duration     |

Use these in Shortcuts automations — for example, run **Check Next Meeting** each morning to get a spoken briefing via a personal automation.

---

## Setting Up Siri Shortcuts

On iOS 16.4 and later, shortcuts are suggested automatically after you use LucidPal a few times. On earlier versions:

1. **Open the Shortcuts app** — find it on your Home Screen or search in Spotlight.
2. **Tap the + button** — create a new shortcut.
3. **Search for LucidPal** — all LucidPal intents appear in the app actions list.
4. **Add a Siri phrase** — tap **Add to Siri** and record your preferred trigger phrase.

---

## How It Works

Because LucidPal runs entirely on-device, Siri can't process your request directly. Instead:

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

| Last action                    | What happens                                                |
| ------------------------------ | ----------------------------------------------------------- |
| Delete event                   | Restores the deleted event to your calendar                 |
| Create event                   | Deletes the newly created event                              |
| Update event                   | Reverts the event to its previous state                      |
| Save note                      | Deletes the saved note                                       |d an event               | LucidPal asks you to confirm, then restores it              |
| Created an event               | LucidPal asks you to confirm, then deletes it               |
| Updated / rescheduled an event | LucidPal informs you that undo of edits isn't supported yet |

---

## Event Preview Card

When a Siri shortcut returns a calendar event (e.g. **Add Calendar Event**, **Delete Calendar Event**, **Check My Calendar**), LucidPal displays an **Event Preview Card** in the conversation thread.

| Element | Description |
|---------|-------------|
| **Date badge** | A compact tile showing the abbreviated month (e.g. "APR") in a coloured header and the day number below |
| **Title** | Event name, truncated to one line |
| **Time range** | Start and end time (e.g. "10:00 AM – 11:00 AM"), or "All day" for all-day events |
| **Calendar name** | The calendar the event belongs to (e.g. "Work", "Personal"), shown in small text |
| **Deleted state** | If the event was deleted: title is struck-through, date badge turns grey, card opacity is reduced, and a green checkmark confirms deletion |

The card's date badge uses a **red header** for active events and a **grey header** for deleted events, matching iOS Calendar's visual language.

---

## Tips

- Shortcuts work on iPhone, iPad, HomePod, AirPods, Apple Watch, and CarPlay.
- You can customize the trigger phrase to anything you like in the Shortcuts app.
- The **Add Calendar Event** shortcut lets you dictate the full event detail in one sentence — Siri passes everything to LucidPal.
- The **Delete Calendar Event** shortcut also responds to _"Delete a LucidPal event"_ and _"Remove event from LucidPal"_.
- The **Undo Last Action** shortcut also responds to _"Undo what I just did in LucidPal"_, _"Undo last LucidPal change"_, _"Restore deleted event in LucidPal"_, and _"Undo LucidPal deletion"_.
- Use **Set Reminder** for notification-based reminders without opening the app. For conversational reminders via AI, see the [Reminders guide](./reminders).
