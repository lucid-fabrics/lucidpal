---
sidebar_position: 10
---

# Cloud AI

On-device AI inference is always free. Cloud AI extends LucidPal with Gemini 2.5 Flash for faster responses and larger context windows.

## Overview

LucidPal uses an **LLMOrchestrator** to route every generation request between cloud and local inference at runtime:

| Route condition | Backend used |
|----------------|--------------|
| `forceLocal = true` | Always local |
| Auto + no paid subscription | Always local |
| Auto + paid subscription + online | Cloud by default |
| Cloud unreachable after 2s (first connect) | Falls back to local |
| Cloud stream dies mid-session after 30s reconnect | Falls back to local |
| Cloud stream fails before first token | One-shot retry with local |

The orchestrator is transparent to callers — `ChatViewModel` and `AgentViewModel` call the same `LLMServiceProtocol` interface regardless of which backend is active.

## Availability

| Feature | Free | Starter | Pro | Ultimate |
|---------|------|---------|-----|----------|
| On-device inference | ✓ | ✓ | ✓ | ✓ |
| Cloud AI chat | — | ✓ | ✓ | ✓ |
| Ability plan synthesis | — | ✓ | ✓ | ✓ |

### Monthly Limits

| Plan | Cloud Messages |
|------|---------------|
| Starter | Standard |
| Pro | Higher |
| Ultimate | Highest |

Limits reset at each billing cycle. When exhausted, on-device AI remains fully available.

---

## How Cloud Routing Works

### First Connect (2s stability timer)

On the first message of a session, LucidPal starts a 2-second stability timer after initiating the cloud connection. If the cloud stream fails to yield any token within 2 seconds, the orchestrator cancels cloud and retries with local inference.

### Mid-Session Reconnect (30s stability timer)

If cloud inference becomes unreachable mid-session (network drop, server error), the orchestrator waits up to 30 seconds for the stream to recover before evicting the local model and switching to cloud.

### Local Model Eviction

When cloud is active and stable, LucidPal evicts the local model from memory after **30 seconds** to conserve RAM. The next time local inference is needed, the model reloads automatically — expect a brief cold-start delay.

### One-Shot Cloud Fallback

If the cloud stream fails **before yielding any token** (connection error at the transport layer), the orchestrator makes a single retry attempt with local inference before surfacing an error to the UI.

### Timeout Behavior

| Scenario | What happens |
|----------|-------------|
| Cloud stream times out | Partial content is shown with a notice appended |
| Task cancelled by user | Partial content kept, no error shown |
| Context window full | Generation stops at last usable position |

---

## Preferred Source Setting

In **Settings → Inference → Preferred Source**:

| Setting | Behavior |
|---------|----------|
| **Auto** (default) | Orchestrator decides based on subscription, connectivity, and stability timers |
| **On-Device Only** (`forceLocal = true`) | Cloud is never used — forces local even with paid subscription |

On-Device Only is useful for airplane mode, battery saving, or when you want zero network traffic.

---

## Error States

| Error | Cause | Recovery |
|-------|-------|----------|
| `dailyLimitReached` | Cloud credits exhausted for this billing cycle | Use on-device, or wait for reset |
| `notAuthenticated` | Auth token expired or revoked | Re-authenticate in Settings → Account |
| `generateFailed` | llama.cpp runtime error | Retry with cloud if available |
| `modelNotLoaded` | Local model not in memory | Wait for reload, or switch to cloud |

---

## Ability Plans (Synthesis)

Synthesis is a single-turn AI call used by ability plans after tool data is gathered on-device. Unlike chat, it does not stream — it takes the gathered context and produces a final response.

Ability plans gather calendar events, notes, or other data locally, then send that context to cloud synthesis for AI-powered summarization or enrichment.

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
