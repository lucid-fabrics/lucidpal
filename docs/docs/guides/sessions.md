---
sidebar_position: 3
---

# Conversations

How to create, manage, and switch between chat sessions in PocketMind.

PocketMind saves each conversation as a separate session. You can pick up any previous chat or start fresh at any time.

## Starting a New Conversation

Tap the **compose** icon in the top-right corner of the session list to start a new chat. Each session gets an automatic title based on your first message.

---

## Switching Between Sessions

The session list shows all your conversations, sorted by most recent activity. Each row shows:

- The conversation title
- The last message preview
- The time of the last message

Tap any session to open it. The full message history loads instantly.

---

## Renaming a Session

Long-press any session in the list, then tap **Rename**. Give it a meaningful name like "Dentist scheduling" or "Work meetings March".

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
> *(PocketMind creates the event)*
> "Actually, make it 11am instead"

The follow-up works because PocketMind remembers the previous message in the same session.

Context is limited based on your device's RAM:

| Device RAM | Messages kept in context |
|-----------|-------------------------|
| Under 6 GB | Last 20 messages |
| 6 GB or more | Last 50 messages |

For very long conversations, start a new session to give the AI a clean slate.

---

## Siri Opens a New Session

When you use a Siri shortcut, PocketMind always opens a **new session** for that request. Your existing conversations are not affected.
