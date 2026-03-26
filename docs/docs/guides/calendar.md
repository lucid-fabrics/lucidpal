---
sidebar_position: 1
---

# Calendar Commands

Natural language examples for creating, updating, deleting, and querying events.

LucidPal understands plain English. You don't need to learn any special syntax — just describe what you want.

## Creating Events

<details>
<summary>Basic event</summary>

> "Add a dentist appointment Friday at 10am"

> "Schedule a team lunch tomorrow at noon"

> "Book a flight on March 25th from 8am to 11am"

</details>

<details>
<summary>With a reminder</summary>

> "Add dentist Friday at 10am, remind me 30 minutes before"

> "Schedule a meeting at 3pm with a 1-hour warning"

</details>

<details>
<summary>All-day event</summary>

> "Add a vacation day next Monday"

> "Block off the whole day on April 5th"

</details>

<details>
<summary>Recurring event</summary>

> "Add a weekly standup every Monday at 9am"

> "Schedule a monthly budget review on the first of every month"

> "Create a daily gym session at 7am until the end of June"

</details>

<details>
<summary>With location or notes</summary>

> "Add dinner at Osteria on Saturday at 7pm, location 123 Main St"

> "Schedule a call with Sarah at 2pm, notes: discuss Q2 roadmap"

</details>

After describing the event, a **preview card** appears in the chat. Tap **Confirm** to save it — or discard if anything looks wrong.

---

## Viewing Your Schedule

> "What's on my calendar today?"

> "Show me everything this week"

> "What do I have Thursday afternoon?"

> "List my events between March 20th and March 25th"

Events appear as cards in the chat, sorted by time. Tap any card to open it in the Calendar app.

:::note
Tapping a card opens the Calendar app scrolled to that date. The view mode (day, week, or month) is determined by whatever you last had open in Calendar — LucidPal cannot control which view opens.
:::

---

## Finding Free Time

> "When am I free tomorrow for an hour?"

> "Find a 90-minute gap this week"

> "What's the first free 2-hour slot between 9am and 6pm today?"

LucidPal scans your calendar and returns available windows that fit your requested duration.

---

## Updating Events

> "Move my dentist appointment to 2pm"

> "Change the team meeting title to 'Weekly Review'"

> "Add a Zoom link to tomorrow's standup"

A preview of the change appears for confirmation before anything is modified.

---

## Deleting Events

> "Cancel my dentist appointment on Friday"

> "Delete the team lunch tomorrow"

> "Remove all my events on Saturday"

A confirmation step appears before deletion. After deleting, an **Undo** button is shown on the card — tap it within the session to restore the event. You can also say _"Hey Siri, undo my last LucidPal action"_ at any time to restore the most recently deleted event, even after the session ends.

:::note
On event cards for created, updated, or rescheduled events, you can also swipe left and tap **Delete** to remove the event directly. A confirmation dialog shows the event name before anything is deleted.
:::

---

## Conflict Detection

If a new event overlaps an existing one, LucidPal shows a warning badge on the preview card. You can still confirm the event — LucidPal will create it regardless, just like the Calendar app would.

---

## Tips

- **Be as natural as you like.** "Next Friday" and "this coming Friday" both work.
- **Time zones.** LucidPal uses your device's current time zone.
- **Relative times.** "In 2 hours", "tomorrow morning", "end of the week" all resolve correctly.
- **Default calendar.** Events are added to your default calendar unless you specify one. Change it in **Settings → Default Calendar**.
