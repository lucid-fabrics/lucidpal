---
sidebar_position: 6
---

# Gmail

LucidPal can read your Gmail inbox so the on-device AI has email context when you ask questions like *"Do I have any unread emails from my boss?"* or *"Find emails about the project proposal."*

All processing happens on your iPhone. Email data never leaves the device.

## What is shared with the AI

Only the following fields are fetched — full email bodies are **never** retrieved:

| Field | Example |
|-------|---------|
| Subject | "Q3 budget review" |
| Sender | "Alice &lt;alice@example.com&gt;" |
| Date | "Nov 4, 2024" |
| Snippet | First ~200 characters of the email |

## Setup

1. Open **Settings** in LucidPal.
2. Scroll to **Data Sources** and enable the **Gmail** toggle.
3. Tap **Sign in with Google** and grant read-only access.
4. Once connected, your account email is shown. The AI fetches your emails on demand when you ask about them.

## Permissions

LucidPal requests the `gmail.readonly` OAuth scope — read-only access. It cannot send, delete, modify, or mark emails as read.

## Searching emails

When you ask the AI to find specific emails, it uses Gmail's server-side search to filter results. Examples:

- *"Find emails from John about the contract"*
- *"Show me unread emails from this week"*
- *"Any emails with attachments from my accountant?"*

The AI issues a targeted Gmail search and synthesizes the results locally.

## Disconnect

To revoke access, tap **Disconnect** in **Settings → Gmail**. This signs out of Google and removes all cached tokens. You can also revoke access at any time from [myaccount.google.com/permissions](https://myaccount.google.com/permissions).

## Privacy

- Tokens are stored in the iOS Keychain, sandboxed to LucidPal.
- No email data is ever sent to a server — the on-device LLM processes everything locally.
- Snippets are only held in memory during a conversation and discarded when the session ends.
