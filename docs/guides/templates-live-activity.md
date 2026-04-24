---
sidebar_position: 15
---

# Conversation Templates & Live Activity

Start chats faster with built-in AI personas, and track generation progress on the Dynamic Island.

---

## Conversation Templates

Templates are built-in AI personas that configure LucidPal for a specific task. They appear as **horizontally-scrollable pill buttons** in the empty state — when a session has no messages yet.

| Template | Icon | Best for |
|----------|------|----------|
| Writing Coach | pencil.and.outline | Drafting, editing, and improving text |
| Decision Helper | scale.3d | Weighing options and making choices |
| Meeting Prep | calendar.badge.checkmark | Briefing before a call or event |
| Brainstorm | lightbulb | Generating ideas without constraints |
| Sales Call | briefcase | Prospect calls — objections, commitments, signals |
| Interview | microphone | Job interviews — candidate responses and strengths |
| 1:1 | person.2 | One-on-one meetings — feedback, blockers, decisions |
| Standup | bolt | Daily standups — yesterday, today, blockers |
| Lecture | book | Classes — key concepts, definitions, formulas |

Each template appends a focused instruction to the system prompt for that session, adjusting tone and approach. You can still send any message — the template just sets the initial context.

:::tip
Start a **Meeting Prep** session before an important call. LucidPal can reference your calendar to pull in the event details automatically.
:::

---

## Chat Banners

LucidPal shows contextual banners at the top of the chat area to communicate status. All banners use a slide-in/fade animation.

| Banner | When shown | Color | Dismissible? |
|--------|-----------|-------|-------------|
| **AI loading** | Model is warming up after launch | Accent (purple) | No — disappears automatically |
| **AI not set up** | No model downloaded yet | Accent (purple) | No — resolves when a model is downloaded |
| **Error** | A generation or tool error occurred | Red | Yes — tap the ✕ button |
| **AirPods connected** | AirPods are paired and auto-listening is active | Green | No — disappears when AirPods disconnect |

### AI Loading Banner

Shows a shimmer sparkles icon and the message *"Just a moment — your AI is getting ready…"* with a spinner. Displayed while the model file is being loaded into memory after the app starts.

### AI Not Set Up Banner

Shows a download icon with *"Your AI isn't set up yet. Go to the Settings tab to download a model — it only takes a minute."* Shown when no model has been downloaded.

### Error Banner

Shows a red triangle with the error message (up to 3 lines). Tap the **✕** button to dismiss.

### AirPods Banner

Shows a green pulsing dot and *"AirPods connected — auto-listening active"* when AirPods Pro are connected and the auto-listening feature is enabled.

---

## Live Activity / Dynamic Island

While LucidPal is generating a response, a Live Activity tracks progress in real time on supported iPhones. An elapsed-seconds counter updates every second so you always know how long the model has been thinking.

- Starts the moment generation begins.
- Disappears automatically 2 seconds after the response is complete.
- You can navigate away from LucidPal — the indicator stays visible so you know when to return.

:::note
Live Activity requires a **Pro or Ultimate** subscription. It is not available on the Free or Starter plans.
::: 

### Lock Screen / StandBy

On the Lock Screen (and in StandBy mode) the banner shows:

| Element | Detail |
|---------|--------|
| ✦ Sparkles icon | Purple, left-aligned |
| Heading | "LucidPal is thinking…" |
| Prompt preview | First line of your message (truncated to 80 characters) |
| Elapsed timer | Seconds counter, right-aligned |

### Dynamic Island — Compact (iPhone 14 Pro and later)

When the Dynamic Island is collapsed, LucidPal occupies both sides:

| Side | Content |
|------|---------|
| Leading (left) | Purple sparkles icon |
| Trailing (right) | Elapsed seconds counter |

### Dynamic Island — Expanded

Tap the Dynamic Island to expand it:

| Region | Content |
|--------|---------|
| Leading | Purple sparkles icon + "LucidPal" label |
| Trailing | Elapsed seconds counter |
| Bottom | Spinner + "Thinking…" label |

### Dynamic Island — Minimal

On iPhones displaying two simultaneous Live Activities, LucidPal shows only the purple sparkles icon.

### Devices without a Dynamic Island

On older iPhones the activity appears as a Lock Screen banner with the same layout described in the Lock Screen section above.

:::note
Live Activity updates happen on-device. No data is sent externally during generation.
:::
