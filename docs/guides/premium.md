---
sidebar_position: 20
---

# Premium

LucidPal's premium tier and entitlement system.

---

## Overview

LucidPal uses a built-in entitlement manager (`PremiumManager`) to gate features by subscription level. The manager is available throughout the app as an `@EnvironmentObject` so any view can check the current entitlement without making a network call.

:::note
In the current release, **all users have Pro access** — no purchase is required. The premium infrastructure is in place for a future paid tier.
:::

---

## Entitlement Levels

| Entitlement | Description |
|-------------|-------------|
| **Free** | Base tier — core AI chat, calendar, and notes |
| **Pro** | Full access to all features, including advanced inference controls and future premium additions |
| **Lifetime** | Same as Pro, unlocked permanently via a one-time purchase |

---

## How It Works

`PremiumManager` is an `ObservableObject` that publishes `isPro: Bool` and the raw `PremiumEntitlement` value. Views observe it to show or hide premium-only UI.

```swift
// Example: check pro status in a SwiftUI view
@EnvironmentObject var premium: PremiumManager

if premium.isPro {
    // show advanced feature
}
```

Because `isPro` is currently `true` for all users, no paywall or upgrade prompt will appear. When the paid tier launches, `PremiumManager` will validate receipts via StoreKit and update `isPro` accordingly — no view changes required.

---

## Pro-Gated Features

The following capabilities require a Pro (or Lifetime) entitlement:

- **Gmail integration** — read your Gmail inbox and send emails directly via Google API (`gmailIntegration` gate). iOS does not allow reading emails through the system Mail app; Gmail's API is the only way to give the AI inbox access. See [Gmail](./gmail).
- Document attachment in agent mode — attach PDFs and text files to agent tasks (`canAttachDocuments` gate)
- Extended context window sizes
- Priority model downloads
- Cloud sync for notes and sessions (opt-in)
- Advanced analytics and habit insights

:::tip
If you are using LucidPal today, you already have access to everything — including features that will become Pro-only in a future version.
:::

---

## Feature Gates

Feature availability is checked via the `FeatureGate` enum. The `canAttachDocuments` gate guards document attachment in agent mode — it returns `true` for Pro and Lifetime users. Views observe this gate via `PremiumManager` to show or hide the document picker button.
