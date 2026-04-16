---
sidebar_position: 3
---

# Conversations

How to create, manage, and switch between chat sessions in LucidPal.

LucidPal saves each conversation as a separate session. You can pick up any previous chat or start fresh at any time.

## Home Screen

When you open LucidPal, the home screen greets you with an at-a-glance view of your day before you start a conversation.

### Greeting and date

A time-based greeting appears at the top — "Good morning", "Good afternoon", "Good evening", or "Good night" — alongside today's weekday, month, and date.

### Today's events

Below the greeting, LucidPal shows how many calendar events you have today: "3 events today" or "Free today" if your calendar is clear.

### Next Event Card

If you have an upcoming event, a tappable card shows its title and how long until it starts (for example, "in 45 min"). Tap the card to ask LucidPal anything about that event. See the [Calendar guide](./calendar) for everything you can do with calendar events.

### Mic button

The large mic button in the centre of the screen starts a voice conversation. Two rings of icons orbit around it — calendar, mic, bolt, grid, and brain — with a subtle 3D depth effect. Tap it to speak your request. See the [Siri & Voice guide](./siri) for tips on voice input.

A short hint below the button changes based on context to suggest what you can ask.

### Quick-action chips

Three chips sit below the mic button for common requests:

- **What's on today?** — summarises your day's events
- **When am I free?** — finds open time in your schedule
- **Find a free slot** — suggests a time for something new

Tap any chip to send that question instantly.

### New text chat

Tap **New text chat** to open a keyboard-based conversation instead of using voice. From a text session you can also capture [Notes](./notes) and ask about [habits](./habit-tracker) or [documents](./document-summarization).

---

## Suggested Prompts

When you open a text chat session before typing anything, LucidPal shows four contextual prompt chips above the input bar. These are generated automatically based on your calendar data, time of day, and day of week — no configuration required.

### What they look like

Each chip is a tappable rounded pill with full-width text. Tap one to instantly pre-fill the input bar and send that question — no typing needed. While the prompts are loading, animated shimmer chips appear as placeholders.

### How they are chosen

LucidPal picks four prompts across four categories every time you open a new chat:

| Category | Examples |
|---|---|
| Schedule overview | "What's my day looking like?", "What's left on my schedule today?", "What's on my agenda tomorrow?" |
| Next specific event | "When does [Event] start?", "How long until [Event]?", "What time is [Event] tomorrow?" |
| General productivity | "Help me draft a quick email", "Summarize my day for me", "Help me write a short message" |
| Contextual utility | "When am I free today?", "What's on this weekend?", "What's my busiest day this week?" |

The exact wording adapts to context:

- **Time of day** — morning prompts focus on planning ahead; evening prompts lean toward review and wind-down.
- **Day of week** — Monday mornings show weekly-overview prompts; Thursdays and Fridays surface weekend-availability prompts.
- **Your calendar** — if you have a specific event coming up soon, its title appears directly in the prompt (e.g. "How long until Team Standup?").

### Without calendar access

If you have not granted calendar permission, LucidPal still shows four general productivity prompts (writing, decision-making, task management) that do not require any calendar data.

### Updating suggestions

Suggested prompts are generated fresh each time you open a new chat session. They are not stored or personalised over time — each session starts from the current calendar state and time.

### Search empty state

If you search for a session and nothing matches, a message confirms that no sessions were found. Clear the search to return to the full list.

---

## Starting a New Conversation

Use the **mic button** on the home screen to start a voice conversation, or tap **New text chat** for a keyboard-based session. Each session gets an automatic title based on your first message.

---

## Switching Between Sessions

The session list shows all your conversations, sorted by most recent activity. Each row shows:

- The conversation title
- The last message preview
- The time of the last message

Tap any session to open it. The full message history loads instantly.

---

## Pinning a Session

Swipe right on any session and tap **Pin** to keep it at the top of the list. Pinned sessions show an orange pin icon in the row. Tap **Unpin** from the same swipe action (or long-press → **Unpin**) to remove the pin.

---

## Renaming a Session

Swipe right on any session and tap **Rename**, or long-press any session and tap **Rename** from the context menu. Give it a meaningful name like "Dentist scheduling" or "Work meetings March".

---

## Session Storage

Sessions are stored individually on your device with no enforced count limit. Each session file is small (text only), so hundreds of sessions have negligible storage impact.

:::tip
If you have many old sessions, use **Edit → Select All → Delete** to clear them in one step and keep the list tidy.
:::

---

## Deleting Sessions

**Single session:** Swipe left on a session and tap **Delete**.

**Multiple sessions:** Tap **Edit** to enter selection mode, select the sessions you want to remove, then tap **Delete**.

**All sessions:** Tap **Edit → Select All → Delete**.

:::warning
Deleted sessions cannot be recovered. Events that were created from a session remain in your calendar.
:::

---

## Conversation Context

Each session remembers its own message history. The AI uses recent messages as context when answering follow-up questions:

> "Add a dentist appointment Friday at 10am"
> _(LucidPal creates the event)_
> "Actually, make it 11am instead"

The follow-up works because LucidPal remembers the previous message in the same session.

Context is limited based on your device's RAM:

| Device RAM   | Messages kept in context |
| ------------ | ------------------------ |
| Under 6 GB   | Last 20 messages         |
| 6 GB or more | Last 50 messages         |

For very long conversations, start a new session to give the AI a clean slate.

---

## In-Chat Search

Tap the **magnifying glass** icon in the top-right toolbar to open a search bar inside the current conversation. Type any keyword — messages that don't match fade out, leaving only the relevant bubbles visible. Tap the **×** inside the search bar to clear the query, or tap the magnifying glass again to close the bar entirely.

---

## Chat Toolbar Actions

The top-right corner of any open chat shows up to four controls:

| Control | What it does |
|---|---|
| **Thinking** pill (brain icon) | Toggles Thinking mode for this session. Highlighted in accent colour when active. See [AI Models → Thinking Mode](./models#thinking-mode). |
| **Magnifying glass** | Opens the in-chat search bar. |
| **Share** (box-and-arrow) | Exports the full conversation as plain text. Only appears when the session has messages. |
| **Clear** | Permanently deletes all messages in the current session (confirmation required). Only appears when the session has messages. |

Tap the **session title** in the navigation bar to rename the session inline — an alert appears with a text field pre-filled with the current name.

---

## Message Bubble Interactions

### Tap — show timestamp

Tap any message bubble to reveal the exact time that message was sent. Tap again to hide it.

### Swipe right — reply

Swipe a bubble to the right to quote it in a reply. A reply preview bar appears above the input field showing the quoted message. Tap **×** in that bar to cancel the quote before sending.

### Long-press — context menu

Long-press any bubble to open the context menu:

| Action | Applies to | What it does |
|---|---|---|
| **Copy** | All messages | Copies the message text to the clipboard. |
| **Share** | All messages | Opens the iOS share sheet with the message text. |
| **Pin** | User messages only | Pins the text as a reusable prompt chip above the input bar. |
| **Delete** | All messages | Removes that single message from the session (cannot be undone). |

### Scroll-to-bottom button

When you scroll up through a long conversation, a circular **↓** button appears in the lower-right corner of the message list. Tap it to jump back to the most recent message.

---

## Pinned Prompts

Pinned prompts are user-created shortcuts — different from the AI-generated [Suggested Prompts](#suggested-prompts) shown at the start of a new session.

To pin a prompt: long-press a **user** message bubble → **Pin**.

Pinned prompts appear as horizontal chips above the input bar whenever the text field is empty. Each chip shows the first 30 characters of the saved text. Tap a chip to pre-fill the input bar with that text so you can edit or send it immediately.

To remove a pinned prompt: long-press the chip → **Remove**, or tap the chip to fill the input and edit it instead.

---

## Bulk Calendar Deletion Bar

When LucidPal proposes deleting two or more calendar events at once, a **bulk action bar** appears below the event cards in the assistant reply. It shows how many events are pending deletion and offers two buttons:

- **Delete All** — confirms all pending deletions in one tap.
- **Keep All** — cancels all pending deletions in one tap.

Individual event cards still have their own confirm/cancel buttons if you want to act on each event separately.

---

## Voice Recording Overlay

When you tap the **mic** button in the input bar, the full chat screen is replaced by a fullscreen **Voice Recording Overlay**. It shows:

- A live transcript of what you are saying (updates in real time).
- A **spinning indicator** while audio is being transcribed after you stop speaking.
- A **Confirm** button to accept the transcript and fill the input bar.
- A **Cancel** button to discard the recording and return to the keyboard.

This overlay is distinct from the home screen mic button, which starts an automatic voice session. The input-bar mic is for dictating a single message inside an existing chat.

---

## Generation Controls

While the AI is generating a response, the send button is replaced by a **stop button** (red circle with a square). Tap it to cancel the current generation immediately. The partially generated text remains in the conversation.

---

## Toasts

Brief toast notifications slide up from the bottom of the chat when a background action completes (for example, after a calendar event is created or a note is saved). They disappear automatically after a few seconds.

---

## Downloading a Model While Chatting

If you try to use the input bar while a model is still downloading, a download progress sheet appears. It shows the model name, a progress bar, and a percentage counter. Tap **Got it** to dismiss the sheet — the download continues in the background and the input bar unlocks automatically when the model is ready.

---

## Siri Opens a New Session

When you use a Siri shortcut, LucidPal always opens a **new session** for that request. Your existing conversations are not affected.