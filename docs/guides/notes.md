---
sidebar_position: 6
---

# Notes

Capture, organise, and interact with AI-enriched notes in LucidPal — all stored on-device.

---

## Notes List

The Notes tab shows your notes in a two-column card grid against a living aurora background. Colour shifts as you interact — no two sessions look exactly the same.

### Stats Bar

Below the filter row, a compact stats bar shows at a glance:

| Pill | Meaning |
|------|---------|
| `N notes` | Total notes in the store |
| `N pinned` | Notes currently pinned |
| `N enriched` | Notes that have an AI summary |

### Filtering by Category

LucidPal's AI automatically assigns every note a category when you save it. Tap a chip to filter to that category — the chip glows with an orange gradient when active.

| Category | Icon | Typical content |
|----------|------|-----------------|
| Idea | 💡 | Creative concepts, brainstorming |
| Task | ✅ | Actionable to-dos |
| Journal | 📓 | Personal reflections |
| Health | 🏥 | Fitness, wellness, medical |
| Goal | 🎯 | Objectives and milestones |
| Memory | 🧠 | Things to remember |
| Finance | 💰 | Budgets, expenses |
| Other | 📝 | Everything else |

Tap **All** to remove the filter.

### Source Badges

Every note carries a source showing how it entered LucidPal:

| Source | Icon | How it enters |
|--------|------|--------------|
| Manual | ✏️ | Created or typed directly in the Notes editor |
| Conversation | 💬 | Saved from a chat with the AI |
| Voice | 🎙 | Recorded via the Record tab |
| Photo | 📷 | Captured from an image (vision AI) |
| Siri | 📱 | Saved via Siri ("Save a note in LucidPal") |

### Pinned Notes

Swipe a card to the right and tap **Pin** to pin a note. Pinned notes appear in a horizontal carousel at the top of the list with an orange gradient border so they stand out. Swipe right again and tap **Unpin** to remove.

### Searching

Use the search bar at the top of the Notes tab to search across all note titles, bodies, and tags at once. The category filter is automatically cleared when a search query is active.

---

## Note Cards

Each card in the grid shows:

- **Category icon** with a soft colour background matching the category
- **Title** in bold
- **Preview** — AI summary if available, otherwise the first 100 characters of the body
- **Relative timestamp** (top-right)
- **Pinned indicator** (if pinned)
- **Task count** and **source badge** in the footer row
- **First tag** as a coloured pill

Cards animate in with a spring effect when they first appear.

---

## Opening and Editing a Note

Tap any card to open the Note Editor. The editor uses an animated aurora background whose colour matches the note's AI category — purple for Journal, green for Task, orange for Goal, and so on.

### Read Mode

When you first open a saved note, it opens in **Read Mode**. Content is structured and visually clear:

1. **Hero Header** — title, category badge, creation date, source, estimated reading time, and a pin toggle button
2. **AI Summary** *(if present)* — a frosted card with an orange gradient border showing the AI-generated summary in italic
3. **Body** — parsed and rendered with full formatting (see [Markdown Support](#markdown-support) below)
4. **AI Action Items** *(if present)* — a separate tappable checklist of tasks the AI extracted
5. **Tags** — your custom tags shown as orange pills

Tap anywhere in the header, body, or tags area to switch to **Edit Mode**.

### Edit Mode

Edit mode provides a full-screen text editor with a **formatting toolbar** pinned above the keyboard:

| Button | What it inserts |
|--------|----------------|
| **H1** | `# ` — renders as a large heading |
| **H2** | `## ` — renders as a medium heading |
| **B** | `****` — wrap selected text in `**` for bold |
| _I_ | `**` — italic markers |
| ☐ Task | `- [ ] ` — an interactive checkbox line |
| • List | `- ` — a bullet point |
| — Line | `---` — a horizontal divider |

A status bar beneath the text area shows live **word count**, **character count**, and **estimated reading time**.

Tap **Save** to save and return to Read Mode. Tap **Cancel** to discard changes.

---

## Markdown Support

Note bodies support a subset of Markdown. In Read Mode these are rendered visually; in Edit Mode you see raw text.

### Supported Syntax

```
# Heading 1
## Heading 2

**Bold text**  _Italic text_  `inline code`

- [ ] Pending task
- [x] Completed task

- Bullet point
- Another point

---

Regular paragraph text.
```

### Interactive Checkboxes

Any line starting with `- [ ]` renders as a tappable checkbox. Tap it to mark it complete:

- The checkbox fills with an orange gradient
- The text gains a strikethrough
- The `[ ]` in the underlying text changes to `[x]` and the note auto-saves

Tap a completed `[x]` item to un-check it.

:::tip Checklist notes
The Task formatting button inserts `- [ ] ` at the cursor, making it fast to build a checklist. Mix regular paragraphs and checkboxes freely — they all render correctly in Read Mode.
:::

---

## AI Summary and Action Items

When a note is saved, LucidPal's on-device AI analyses the body and may add:

| Field | What it shows |
|-------|--------------|
| **Summary** | A one-sentence description of the note's content |
| **Action Items** | Actionable tasks detected in the body |
| **Category** | The most relevant category from the list above |

These fields appear automatically — you do not need to do anything to trigger enrichment. The **AI Summary** card appears at the top of the Read view, above the body. The **Action Items** card appears below the body and uses tappable checkboxes.

### Voice Session AI Fields

Notes recorded via the **Record tab** receive additional AI-enriched fields from the transcript analysis:

| Field | What it shows |
|-------|--------------|
| **Chapters** | Timestamped segments with titles and AI summaries |
| **Highlights** | Key moments or statements extracted from the conversation |
| **Decisions** | Decisions made during the session, with checkmark icons |
| **Follow-up Draft** | AI-generated email draft ready to copy and send |

Chapters, highlights, decisions, and follow-up draft appear in the note's Read view below the body and action items. They are populated by `NoteEnrichmentService` after the recording is processed — see [Record Sessions](./record-sessions.md) for the full workflow.

### NoteAttachments (Cloud Storage)

Voice notes may include file attachments (audio recordings, exported transcripts). These are stored via **Cloudflare R2** when cloud sync is enabled:

- Each attachment has an `r2Key` pointing to the object in R2 storage and a `localURL` for on-device cache
- Attachments are uploaded after recording processing completes
- The Notes list shows attachment size and upload status on the card footer

This enables offline access while keeping the option to sync attachments across devices when connected.

:::note On-device only
All AI enrichment runs locally on your device using the currently loaded model. No note content is sent to any server. Enrichment requires a model to be loaded.
:::

Action item checkboxes in the AI Action Items card are **session-only** — ticking them helps you track progress while the note is open, but the ticks reset the next time you open the note. To persist completion state, add the tasks to the body as `- [ ]` lines instead.

---

## Pinning from the Editor

In Read Mode, the **pin icon** in the top-right of the Hero Header toggles the pin state without leaving the editor. The icon animates with a spring effect and the change is saved immediately.

---

## Sharing a Note

In Read Mode, tap the **⋯** menu (top-right) and choose **Share** to open the iOS share sheet with the note title and body as plain text.

---

## Recording Voice Sessions

Use the **Record tab** (microphone icon in the tab bar) to record meetings, interviews, and conversations. Live transcription, speaker detection, and AI summaries run automatically. Completed sessions appear in the Notes list with a microphone badge.

For full details, see [Record Sessions](./record-sessions.md).

---

## Creating a Note from Chat

You can ask LucidPal directly:

> "Save a note: buy oat milk and Greek yogurt"

> "Note that I need to review the Q3 report by Friday"

> "Add a note about the meeting — we agreed to ship in May"

The AI creates the note, chooses a title, and queues it for enrichment. The note appears immediately in the Notes tab.

| Command type | Example |
|-------------|---------|
| Create | "Note that…" / "Save a note…" |
| Update | "Update my shopping list — add oat milk" |
| Delete | "Delete my draft note" |
| Search | "Find my notes about the project" |

---

## Storage and Privacy

Notes are stored as a JSON file in your app's Documents directory (`lucidpal_notes.json`) with iOS Complete File Protection. They are **not** uploaded to iCloud or any server.

The store holds up to **500 notes**. When the limit is reached, the oldest note is automatically removed.

See [Privacy](./privacy.md) for full details.
