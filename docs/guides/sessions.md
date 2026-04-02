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

## Siri Opens a New Session

When you use a Siri shortcut, LucidPal always opens a **new session** for that request. Your existing conversations are not affected.
