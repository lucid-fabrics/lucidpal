---
sidebar_position: 9
---

# Synthesis

Single-turn AI generation for ability plans after on-device data gathering.

## Overview

Synthesis is a one-shot AI call used by LucidPal's ability plans. Unlike chat, which streams responses incrementally, synthesis takes gathered context and produces a final response in a single round.

How it works:
1. An ability plan collects calendar events, notes, or other data **on-device**
2. That context is sent to cloud synthesis along with a task prompt
3. Gemini 2.5 Flash generates a final response
4. The response is returned immediately — no streaming, no tool loop

This design keeps sensitive data on-device while still benefiting from cloud AI for complex synthesis tasks.

:::note
Synthesis requires an active paid subscription (Starter, Pro, or Ultimate). On-device AI is not used for synthesis.
:::

---

## How Ability Plans Use Synthesis

Ability plans are specialized workflows for tasks like:

- Summarizing a week of calendar events
- Generating a daily briefing from your notes and events
- Enriching a draft with context from your calendar

The plan gathers the raw data locally, formats it as a prompt, and sends it to synthesis. The AI then produces a polished output in one call.

### Example flow

1. You ask LucidPal: "Give me a summary of my week"
2. The ability plan queries your calendar for the next 7 days **on-device**
3. Events are formatted into a prompt with your request
4. The prompt is sent to the cloud synthesis endpoint
5. Gemini returns a formatted weekly summary
6. You see the result in chat

Your calendar events never leave your device — only the synthesized summary comes back from the cloud.

---

## Error Handling

| HTTP status | Meaning | Resolution |
|-------------|---------|------------|
| 200 | Success | Response contains `text` |
| 402 | Subscription required | Upgrade to Starter, Pro, or Ultimate |
| 429 | Rate limited | Wait and retry |
| 502 | AI service error | Retry later |
| 503 | Cloud AI not configured | Contact support |

:::tip
If synthesis fails, on-device AI remains available. You can continue using LucidPal with local inference while the cloud issue is resolved.
:::

---

## Troubleshooting

### "Subscription required" error

Synthesis is only available for paid subscribers.

1. Open **Settings → Subscription**
2. Verify your plan is active
3. If expired, renew to restore access

### "Monthly limit reached" error

- On-device AI inference remains available
- Upgrade your plan for higher limits
- Wait until your next billing date
