---
sidebar_position: 7
---

# Microsoft Exchange

LucidPal can connect to your Microsoft Exchange or Outlook account so the on-device AI has email and calendar context when you ask questions like *"Do I have any unread emails from my manager?"* or *"What's on my Exchange calendar this week?"*

All processing happens on your iPhone. Email and calendar data never leaves the device.

:::info Pro feature
Microsoft Exchange integration requires a **Pro** subscription. See [Premium](./premium) for details.
:::

## What is supported

| Capability | Supported |
|------------|-----------|
| Read email inbox | ✅ |
| Search emails | ✅ |
| Read Exchange calendar | ✅ |
| Write Exchange calendar (add/edit events) | ✅ |
| Send email | ❌ Not available in current version |
| Access shared mailboxes | ❌ Not available |
| Legacy Exchange (EWS) | ❌ Modern auth only |

Exchange calendar events appear alongside your Apple Calendar events in the unified calendar view.

## Supported accounts

Any account that uses **Microsoft 365 modern authentication** works, including:

- Work or school accounts (Microsoft 365 / Office 365)
- Personal Outlook.com / Hotmail accounts
- Exchange Server 2019+ with modern auth enabled

Legacy on-premises Exchange servers using basic authentication (username + password) are **not supported**.

## Setup

1. Open **Settings** in LucidPal.
2. Scroll to **Data Sources** and tap **Microsoft Exchange**.
3. Tap **Connect** and sign in with your Microsoft account.
4. Grant read access to mail and calendar when prompted.
5. Once connected, your account email is shown. The AI will use your emails and Exchange calendar events as context.

:::tip Work accounts
If your organisation requires multi-factor authentication, the sign-in prompt will include it automatically. You may need to complete MFA on your Microsoft Authenticator app.
:::

## Permissions requested

LucidPal requests the following Microsoft Graph scopes:

| Scope | Purpose |
|-------|---------|
| `Mail.Read` | Read your email inbox and search messages |
| `Calendars.ReadWrite` | Read and create Exchange calendar events |
| `openid`, `email` | Basic identity to identify your account |
| `offline_access` | Keep you signed in without repeated prompts |

LucidPal does **not** request permission to send, delete, or modify emails.

## What is shared with the AI

Only lightweight fields are fetched — full email bodies are **never** retrieved:

| Field | Example |
|-------|---------|
| Subject | "Q3 budget review" |
| Sender | "Alice &lt;alice@example.com&gt;" |
| Date received | "Nov 4, 2024" |
| Preview | First ~200 characters of the message |

## Searching emails

When you ask the AI about emails, it issues a targeted Microsoft Graph search and processes the results locally. Examples:

- *"Any unread emails from Sarah?"*
- *"Find emails about the contract renewal"*
- *"Show me emails with attachments from this week"*

## Exchange calendar

Your Exchange calendar events are merged with your Apple Calendar events so the AI always has a complete view of your schedule. You can ask:

- *"What's on my calendar from Exchange this afternoon?"*
- *"Add a team standup to my Exchange calendar every Monday at 9am"*
- *"Cancel my 3pm Exchange meeting"*

## Disconnect

To revoke access, tap **Disconnect** in **Settings → Microsoft Exchange**. This removes all stored tokens from the device. You can also revoke LucidPal's access at any time from [account.microsoft.com/permissions](https://account.microsoft.com/permissions).

## Privacy

- OAuth tokens are stored in the iOS Keychain, sandboxed to LucidPal.
- No email or calendar data is ever sent to a server — the on-device LLM processes everything locally.
- Fetched data is only held in memory during a conversation and discarded when the session ends.
