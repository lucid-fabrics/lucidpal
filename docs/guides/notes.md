---
sidebar_position: 5
---

# Notes

Create, edit, and search personal notes — and let the AI manage them for you.

---

## Overview

LucidPal has a built-in note-taking layer that stores text notes on-device. Notes are private, never uploaded, and instantly searchable. The AI can create, retrieve, and update notes on your behalf directly from the chat.

---

## Viewing Your Notes

Tap the **Notes** tab (notebook icon) in the bottom navigation bar to open the notes list. Notes are sorted by last-modified date. Each row shows the note's **category icon** and an **AI-generated summary** instead of raw body text, so you can scan content at a glance. If a note has extracted action items, a badge shows the count.

Notes created by the AI from a conversation show a small **source icon** to distinguish them from manually written notes.

Tap any note card to open the **Note Detail View**. By default the view is in **read mode** — tap **Edit** (top-right) to enter edit mode and make changes. A **Share** button in the toolbar opens the standard iOS share sheet so you can export the note to any app.

---

## Pinned Notes

Pin any note so it stays visible at the top of the list in a horizontal **pinned carousel**.

- **Pin:** Swipe left on a note card → tap **Pin**
- **Unpin:** Swipe left on a pinned note → tap **Unpin**

Pinned notes still appear in the main list below the carousel (with a pin indicator) and are included in search and category filtering.

---

## Category Filter

Below the pinned carousel, a row of **category chips** lets you filter the note list instantly. Tap a chip to show only notes in that category; tap it again (or tap **All**) to clear the filter.

| Chip | Category |
|------|----------|
| All | Every note |
| 💡 | Idea |
| ✅ | Task |
| 📓 | Journal |
| 🏥 | Health |
| 🎯 | Goal |
| 🧠 | Memory |
| 💰 | Finance |
| 📝 | Other |

Categories are assigned automatically by the AI after you save a note. You cannot set them manually.

---

## Creating a Note Manually

1. In the Notes list, tap the **+** button in the top-right corner.
2. Type a title (optional) and your note body.
3. Tap **Done** in the toolbar — the note appears immediately in the list.

:::tip
Notes support plain text only. Use line breaks to structure content — the AI can read and summarize multi-line notes without any special formatting.
:::

---

## Asking the AI to Manage Notes

The AI can act on notes directly from the chat using natural language. No need to leave the conversation.

### Create a note

> "Save a note: dentist appointment Tuesday at 3 PM"

> "Note that I need to review the project proposal before Friday"

When creating a note the AI can set:
- **Title** — a short label for the note
- **Body** — the full note content
- **Tags** — one or more keywords (e.g. `work`, `health`) for your own reference

### Search notes

> "What notes do I have about the project?"

> "Show me everything I saved this week"

The AI searches note titles and body text and returns up to five matching results as preview cards.

### Update a note

> "Update my shopping list note — add oat milk"

> "Change the title of my dentist note to 'Dentist – rescheduled'"

The AI locates the note by searching first, then patches the **title**, **body**, and/or **tags** you specify. Fields you omit remain unchanged.

### Delete a note

> "Delete my draft ideas note"

> "Remove the note about last week's meeting"

The AI finds the matching note and permanently deletes it. This cannot be undone.

The AI responds with a confirmation card showing the note title and a preview of the content.

:::note
The AI matches your request against note titles and body text. Phrase requests naturally — exact titles are not required.
:::

---

## Save Note via Siri

Use the **Save Note** shortcut to create a note hands-free.

1. Open **Shortcuts** → **Automation**, or ask Siri:
   > "Hey Siri, Save Note in LucidPal"
2. Dictate the note content.
3. LucidPal saves it in the background — no need to open the app.

You can also add the shortcut to your Home Screen or Siri Suggestions for one-tap access.

---

## Searching Notes

In the Notes list, pull down to reveal the search bar. Typing filters notes in real time by title and body content.

---

## AI-Enhanced Notes

After you save a note (manually or via the AI), LucidPal enriches it in the background using the on-device model. No action required on your part.

The AI automatically:

- **Assigns a category** — one of the eight categories listed in the Category Filter section above
- **Generates a summary** — a concise one- or two-sentence recap of the content
- **Extracts action items** — any tasks or to-dos mentioned in the note

Open the note and scroll below the body to find the **AI Insights** section, which shows:

- A category chip
- The generated summary
- Action items rendered as checkboxes

Tap any action item checkbox to send it to LucidPal as a reminder. The app schedules an iOS notification for that item so you get an alert at your chosen time — without leaving the note. See the [Reminders guide](./reminders) for details on how reminders work.

:::note
Enrichment happens after saving and may take a few seconds. If you open a note immediately after creating it, the AI Insights section may still be loading.
:::

---

## Deleting a Note

Swipe **right-to-left** (trailing swipe) on any note card in the list, then tap **Delete**. This action is permanent.

:::warning
Deleted notes cannot be recovered. There is no trash or undo.
:::

---

<details>
<summary>What data is stored and where?</summary>

All notes are saved locally on your device in the app's sandboxed storage. They are included in standard iPhone backups (iCloud or iTunes) if backup is enabled. Notes are never sent to any server.

</details>
