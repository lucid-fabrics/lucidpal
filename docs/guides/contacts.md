---
sidebar_position: 7
---

# Contacts

Ask LucidPal to find contact information without leaving the conversation.

---

## Overview

LucidPal can search your iPhone's Contacts app and display results directly in chat. All lookups happen on-device — contact data is never sent to any server or passed outside the app.

---

## Enabling Contacts Access

The first time you ask the AI about a contact, iOS will prompt you to grant Contacts access. Tap **Allow** to enable the feature.

If you denied access previously:

1. Open **Settings** → **Privacy & Security** → **Contacts**.
2. Find **LucidPal** and set it to **While Using App**.

:::note
LucidPal only reads contacts in response to an explicit request. It does not scan your contacts in the background.
:::

---

## Searching Contacts via Chat

Ask naturally — the AI searches by name, company, or any combination:

> "What's Sarah's phone number?"

> "Find the email for anyone at Acme Corp"

> "Show me contacts named Jordan"

The AI displays a **Contact Card** in the chat with the matched contact's name, phone numbers, email addresses, and company — exactly as stored in your Contacts app.

---

## Find Contact via Siri

Use the **Find Contact** shortcut to look up a contact hands-free:

> "Hey Siri, Find Contact in LucidPal"

Dictate the name or company you're looking for. LucidPal returns the result as a Siri response — no need to open the app.

You can also trigger this from the **Shortcuts** app to build automation workflows (e.g., add to a Shortcut that drafts an email).

---

## What Is Shown in a Contact Card

| Field | Shown if available |
|---|---|
| Full name | Always |
| Phone numbers | Yes — tap to open the Phone dialer |
| Email addresses | Yes — tap to open Mail |
| Company / organization | Yes |
| Notes | No — notes are excluded for privacy |

Phone numbers and email addresses in the card are **tappable**:

- **Phone number** — tapping opens the iOS Phone app dialer directly.
- **Email address** — tapping opens a new message in the Mail app.

If a contact has multiple numbers or emails, each appears as a separate tappable row.

---

## Privacy

Contact data is used only to respond to the current query. LucidPal does not store, index, or cache your contacts beyond the immediate response.

<details>
<summary>What if a contact has multiple matches?</summary>

When a query matches more than one contact, LucidPal shows all matches as separate Contact Cards in the chat. Ask a follow-up question to narrow down — for example: "The one at Acme Corp" or "The one with a 514 area code".

</details>
