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
| **Simple** | Data Sources (Notes, Habits, Contacts, Calendar, Location, Web Search), AI Model (text model picker + Download More), Voice, and General (Notifications, About, Debug Logs) |
| **Advanced** | Everything in Simple, plus: Vision toggle and vision model picker, full Inference controls (context window, temperature, max tokens, timeout, KV Cache info), and Shortcuts/Siri section |

The selected mode is remembered across app launches. New users start in **Simple** mode.

:::tip
Switch to **Advanced** mode when you want to fine-tune how the AI generates responses or configure a vision model. For everyday use, **Simple** mode is all you need.
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
| **Vision** toggle | When on, photo attachments are processed by the vision model. Turn off to force text-only inference and save RAM. |

See [Vision & Photos](./vision-photos) for how to attach and analyze images.

---

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

## Inference

Controls how the AI generates responses.

| Setting | Default | What it does |
|---------|---------|--------------|
| **Start voice on open** | Off | Automatically activates the microphone when you open a new chat |
| **AirPods auto-voice** | Off | Starts listening when AirPods connect; stops on silence |
| **Auto-send after speech** | On | Submits the transcribed message without requiring a tap (hidden when "Start voice on open" is on) |
| **Context Window** | Device max | Tokens the model keeps in memory — larger = longer conversations, more RAM |

Context window options are capped to your device's RAM. The app auto-selects the largest safe value on first launch and after upgrades.

### Advanced Inference Controls

These settings are visible in **Advanced** mode only.

| Setting | Range | Default | What it does |
|---------|-------|---------|--------------|
| **Temperature** | 0.0 – 2.0 | 0.35 | Lower = focused/deterministic; higher = creative/varied |
| **Max Response Length** | 128 – 2048 tokens | 768 | Cap on how long a single reply can be |
| **Timeout** | 30 – 300 s | 90 s | Generation is cancelled if it takes longer than this |
| **KV Cache** | — | Fixed | Shows the quantization type used for the key-value cache (read-only) |

Temperature and context window changes take effect the next time the model loads (i.e., next new chat).

:::tip Thinking Mode
Thinking mode is toggled per-chat via the **brain icon** in the chat toolbar. The last state is remembered across chats. See [AI Models → Thinking Mode](./models#thinking-mode) for details on which models support it.
:::

---

## Notifications

| Setting | What it does |
|---------|--------------|
| **Pre-event reminders** | Sends a notification 10 minutes before each calendar event with a tap-to-prepare shortcut |

Toggling this on triggers an iOS notification permission prompt if not yet granted.

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
