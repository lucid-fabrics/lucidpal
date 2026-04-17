---
sidebar_position: 18
---

# Settings

A reference for every option in the LucidPal Settings screen.

Open Settings by tapping the **gear icon** in the top-right corner of the main screen.

---

## Simple vs Advanced Mode

At the top of Settings, a **segmented picker** lets you switch between two views of the settings screen.

| Mode | What you see |
|------|-------------|
| **Simple** | Data Sources, AI Model, Voice, Sync, and App sections |
| **Advanced** | Everything in Simple, plus: Web Search config, Shortcuts/Siri, and Developer (debug builds) |

The selected mode is remembered across app launches. New users start in **Simple** mode.

:::tip
Switch to **Advanced** mode to access Web Search configuration and Siri Shortcuts. For everyday use, **Simple** mode is all you need.
:::

---

## Data Sources

These toggles control which personal data LucidPal can read and act on. All processing is on-device — nothing leaves your iPhone.

| Section | Toggle | What it does |
|---------|--------|--------------|
| **Notes** | Notes | LucidPal can save ideas when you say "save this" or "make a note" |
| **Habits** | Habits | LucidPal can log and query habits — "log my workout", "did I meditate today?" |
| **Contacts** | Contacts Access | LucidPal can look up phone numbers and email addresses from your contacts |
| **Calendar** | Use calendar in chat | Upcoming events are included in the AI prompt for scheduling and reminders |
| **Location** | Include city in AI context | Your detected city is added to the AI prompt for location-relevant answers |
| **Mail** | Mail | Lets the agent compose outgoing emails using your iOS Mail accounts (any provider). **Cannot read your inbox** — iOS does not expose an API for that. |
| **Gmail** *(Pro)* | Sign in with Google | Connects to Gmail via Google OAuth for inbox reading and sending. Requires Pro. See [Gmail](./gmail). |
| **Microsoft Exchange** *(Pro)* | Connect | Connects to your Microsoft 365 or Outlook account via OAuth for email reading and Exchange calendar sync. Requires Pro. See [Microsoft Exchange](./microsoft-exchange). |
| **Web Search** | *(tap to open sub-screen)* | Configure web search provider and API key — see [Web Search](./web-search) |

### Calendar

The Calendar row adapts to the current permission state:

| State | What you see |
|-------|-------------|
| Not authorized | **Allow Access** button — tap to trigger the iOS permission prompt |
| Authorized | Toggle to include or exclude event context from the AI |

Once access is granted, a **Default Calendar** picker also appears — choose which calendar new events are created in ("System Default" uses the iOS default).

### Location

The Location row shows different states depending on permission:

| State | What you see |
|-------|-------------|
| Not yet requested | **Enable** button — tap to request iOS location permission |
| Granted | Row label shows the detected city inline, e.g. "Location — Montreal" |
| Denied | **Denied** badge — re-enable via iOS Settings → Privacy & Security → Location Services → LucidPal |

The city string is included in the system prompt — never stored on any server.

---

## Vision

| Setting | What it does |
|---------|--------------|
## Text Model

Lists all downloaded and available text models for your device. Tap a model to select and load it.

- A **checkmark** indicates the active model.
- **On device** / **Not downloaded** shows download status.
- File size is shown next to each model name.
- Swipe left on a downloaded model to **Delete** it and recover storage.
- Tap **Download More Models** to browse and download additional models.

Device RAM and available storage are shown in the section footer to help you choose.

For a full model comparison table, see [AI Models](./models).

---

## Vision Model

Lists available vision models (separate from the text model, unless you chose an integrated model).

| Badge | Meaning |
|-------|---------|
| **Integrated** | Single model handles both text and vision — no separate download needed |
| **Vision** | Dedicated vision model — pairs with your text model |

- Tap a downloaded vision model to activate it.
- Tap **Download Vision Models** to fetch one if none are downloaded.
- If no vision models are compatible with your device, the section shows a notice.

---

## Voice

| Setting | Default | What it does |
|---------|---------|--------------|
| **Start voice on open** | Off | Automatically activates the microphone when you open the **Agent** screen |
| **AirPods auto-voice** | Off | Starts listening when AirPods connect; stops on silence |
| **Auto-send after speech** | On | Submits the transcribed message without requiring a tap (hidden when "Start voice on open" is on) |

:::tip Thinking Mode
Thinking mode is toggled per-chat via the **brain icon** in the chat toolbar. The last state is remembered across chats. See [AI Models → Thinking Mode](./models#thinking-mode) for details on which models support it.
:::

---

## Notifications

| Setting | What it does |
|---------|--------------|
| **Pre-event reminders** | Get a notification 10 minutes before each calendar event. Works offline — no internet needed. |

Toggling this on triggers an iOS notification permission prompt if not yet granted. Requires calendar access to be enabled.

:::note
This can also be enabled during initial onboarding on the **Connect Your World** screen.
:::

---

## Shortcuts

LucidPal exposes four actions to the **Shortcuts** app for automation:

| Action | Description |
|--------|-------------|
| **Ask LucidPal** | Query the AI assistant and receive a text response |
| **Create Event** | Add a calendar event with title, time, and duration |
| **Check Next Meeting** | Get details of your next upcoming calendar event |
| **Find Free Time** | Search for available time slots in your calendar |

Tap **Open Shortcuts App** to jump directly to the Shortcuts app and build automations.

### Action parameters

| Action | Parameters | Defaults |
|--------|------------|---------|
| **Ask LucidPal** | `query` (text) | — |
| **Create Event** | `eventTitle`, `startTime`, `durationMinutes` | duration: 60 min |
| **Check Next Meeting** | *(none)* | — |
| **Find Free Time** | `searchDate`, `durationMinutes` | date: now, duration: 60 min |

Empty or whitespace-only inputs are rejected — the action returns an empty result rather than creating a malformed entry.

See [Siri & Shortcuts](./siri) for step-by-step automation examples.

---

## About

Shows the app version and build number.

### Debug Logs

Tap **Debug Logs** to open an in-app log viewer that captures real-time events from the AI, voice transcription, calendar, and other subsystems.

| Control | What it does |
|---------|--------------|
| **Filter (funnel icon)** | Filter entries by category (LLM, Whisper, Calendar, …) or log level (info / warning / error) |
| **Search bar** | Full-text search across all log messages |
| **Copy icon** | Copies the filtered log as plain text — paste into a bug report or email |
| **Trash icon** | Clears all log entries |

Logs are stored in memory only and are cleared when you quit the app. If you are reporting a bug, reproduce the issue and then tap the copy icon before closing the app.
