---
sidebar_position: 10
---

# Cloud AI

On-device AI inference is always free and runs locally. Cloud AI extends LucidPal with cloud-powered responses via Gemini 2.5 Flash.

## Overview

Cloud AI offers:
- **Faster responses** — Gemini 2.5 Flash runs on cloud infrastructure
- **Extended context** — larger context windows for complex conversations
- **Ability plans** — single-turn synthesis for specialized tasks after on-device data gathering

:::note
Cloud AI requires an active paid subscription (Starter, Pro, or Ultimate).
:::

---

## Availability

| Feature | Free | Starter | Pro | Ultimate |
|---------|------|---------|-----|----------|
| On-device AI inference | ✓ | ✓ | ✓ | ✓ |
| Cloud AI chat | — | ✓ | ✓ | ✓ |
| Ability plan synthesis | — | ✓ | ✓ | ✓ |

### Monthly Limits

| Plan | Monthly Messages |
|------|-----------------|
| Starter | Standard |
| Pro | Higher |
| Ultimate | Highest |

Limits reset at the start of each billing cycle. When you reach your limit, on-device AI remains fully available.

:::tip
On-device AI is always available even after cloud limits are reached. You can continue using LucidPal with local inference at no extra cost.
:::

---

## How Cloud AI Works

1. Your message and conversation history are sent to the Gemini API
2. Responses stream back via Server-Sent Events (SSE)
3. Text appears incrementally in chat as it generates

LucidPal automatically selects cloud AI when you have an active subscription and are online. It falls back to on-device AI seamlessly when offline.

---

## Ability Plans (Synthesis)

Synthesis is a single-turn AI call used by ability plans after tool data is gathered on-device. Unlike chat, it does not stream — it takes the gathered context and produces a final response.

Ability plans gather calendar events, notes, or other data locally, then send that context to cloud synthesis for AI-powered summarization or enrichment.

---

## Switching Between Cloud and On-Device

LucidPal automatically selects the best inference source based on:
- Your subscription tier
- Available credits
- Network connectivity

You can override this in **Settings → Inference → Preferred Source**.

| Setting | Behavior |
|---------|----------|
| Auto | App selects based on context |
| On-Device Only | Always use local AI |

---

## Troubleshooting

### "Subscription required" error

Cloud AI requires an active paid subscription (Starter, Pro, or Ultimate).

1. Open **Settings → Subscription**
2. Verify your plan is active
3. If expired, renew to restore access

### "Monthly limit reached" error

You've used your allocated cloud AI messages for this billing cycle.

- Use on-device inference for the rest of the cycle
- Upgrade your plan for higher limits
- Wait until your next billing date

### Entitlement changes not reflected

If you subscribe or cancel while the app is open:

1. Close and reopen LucidPal
2. The app refreshes entitlements on launch
