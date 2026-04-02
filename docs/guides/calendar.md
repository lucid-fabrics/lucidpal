---
sidebar_position: 1
---

# Calendar Commands

Natural language examples for creating, updating, deleting, and querying events.

LucidPal understands plain English. You don't need to learn any special syntax — just describe what you want.

:::note What LucidPal can see
When calendar access is enabled, LucidPal automatically loads your events from **2 days in the past to 16 days ahead**. This context is what lets it reference existing events by name, detect conflicts, and use precise event IDs for reschedules. Events outside this window are not visible to the AI — if you need to act on something further out, mention the exact title and date.
:::

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

## Rescheduling Events

> "Reschedule my dentist appointment to Monday at 3pm"

> "Move the team standup tomorrow to 10am"

> "Push my Friday lunch to next Friday"

LucidPal identifies the event directly by its calendar ID, so even when you have similarly named events the correct one is updated. A preview of the new time appears for confirmation before the change is saved.

:::note
Reschedule keeps all other event details — title, location, notes, and attendees — unchanged. Only the start and end times move.
:::

---

## Conflict Detection

If a new event overlaps an existing one, LucidPal shows a warning badge on the preview card. An orange triangle appears in the top-right corner of the card.

Tap the warning badge or the card itself to open the **Scheduling Conflict** sheet. The sheet lists each overlapping event — its title, time range, calendar name, and a "Recurring" tag if applicable — then offers three actions:

| Action | What it does |
|--------|-------------|
| **Keep Anyway** | Confirms the event as-is, overlap included |
| **Find Free Slot** | Searches the next 7 days for gaps that fit the event's duration (up to 5 results shown) |
| **Cancel Event** | Discards the pending event |

When free slots are found, the sheet expands to show each available window. Tap any slot to reschedule the event to that time and confirm in one step.

## Undo

After any calendar write (create, update, reschedule, or delete), an **Undo** button appears on the result card. Tap it during the same session to reverse the action immediately.

For deletions specifically, you can also say _"Hey Siri, undo my last LucidPal action"_ at any time — even after closing the app — to restore the most recently deleted event.

## Free Slot Results Card

When you ask LucidPal to find free time, results appear as an **Available Slots** card in the chat. Each row shows the day, date, and time window. Tap any row to open the Calendar app scrolled to that moment so you can create an event manually, or ask LucidPal to schedule something there.

## Event List Card

When a query returns multiple events (e.g. "What's on my calendar this week?"), results appear as a **grouped event list card** — a single card containing all matching events as tappable rows.

- The **header** shows the date or date range and the total event count (e.g. "Today · 3 events" or "Mon, Apr 7 – Wed, Apr 9 · 5 events"). Tapping the header opens the Calendar app at the first event's date.
- Each **row** shows the event title, time range, calendar name, and location (if set). A colored accent bar on the left helps visually distinguish consecutive events.
- Tapping any row opens the Calendar app scrolled to that specific event.

This card is distinct from the single-event **preview card** used during create/update flows (which shows a Confirm button). The event list card is read-only and appears only for query results.

## Event Cards in Detail

### While a write is in progress

A **"Updating calendar…"** pill with a pulsing calendar icon appears in the chat while LucidPal is saving your event. It is replaced by the result card once the operation completes.

### Pending deletion

When you ask to delete an event and LucidPal needs confirmation, a pending-deletion card appears with the event details and two inline buttons:

- **Keep** — cancels the deletion
- **Delete** (red) — confirms and removes the event

### Pending update

When you ask to update an event (title, time, location, or reminder), a pending-update card shows the current value crossed out next to the proposed value for each changed field. Two inline buttons let you **Cancel** or **Apply** the change.

---

## Tips

- **Be as natural as you like.** "Next Friday" and "this coming Friday" both work.
- **Time zones.** LucidPal uses your device's current time zone.
- **Relative times.** "In 2 hours", "tomorrow morning", "end of the week" all resolve correctly.
- **Default calendar.** Events are added to your default calendar unless you specify one. Change it in **Settings → Default Calendar**.

:::tip Use your current location
You can ask LucidPal to fill in your location automatically:

> "Add a meeting here at 3pm"

> "Create a lunch event at my current location"

LucidPal resolves your city via on-device reverse geocoding and sets it as the event location. It requests location access the first time — you can manage this in **iOS Settings → Privacy & Security → Location Services → LucidPal**.
:::

---

## Troubleshooting

### Calendar access denied

If LucidPal cannot read or write calendar events, it has no permission to do so.

**Fix:** Go to **iOS Settings → Privacy & Security → Calendars → LucidPal** and enable access. Then return to the app and repeat your request.

### Event not found

For **reschedule** operations, LucidPal uses the event's internal calendar ID. For **update** and **delete** operations, it searches by title within a 60-day window. If the event was deleted outside the app, renamed, or its ID changed (e.g. after a calendar sync error), LucidPal will report that the event could not be found.

**Fix:** Check the Calendar app to confirm the event still exists. If it does, try referencing it again with its exact title and — for reschedule — ask LucidPal to find and reschedule it so it can pick up the current ID.

### Event saved but not opening correctly

In rare cases an event is saved to the calendar but its identifier cannot be retrieved immediately (e.g. due to a sync delay with iCloud or Exchange). The event will still appear in your calendar — the identifier is only needed for deep-linking from the app.

**Fix:** Open the Calendar app manually to verify the event was created. If it is missing, try creating it again.

<details>
<summary>For developers</summary>

See [architecture/free-slot-engine](../architecture/free-slot-engine) for how free-slot search and conflict detection are implemented.

</details>
