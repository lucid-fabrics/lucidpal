---
sidebar_position: 4
---

# AI Models

Choosing and downloading the right model for your iPhone.

LucidPal runs an AI model entirely on your device. On first launch, you'll be prompted to download one. The app recommends the best model for your iPhone automatically.

## Available Models

| Model              | Download size | Min RAM  | Best for                                       |
| ------------------ | ------------- | -------- | ---------------------------------------------- |
| Qwen3.5 0.8B       | 0.51 GB       | 3 GB RAM | iPhone SE / older devices — fastest, text only |
| Qwen3.5 2B         | 1.27 GB       | 5 GB RAM | iPhone 12–14 standard — balanced text + vision |
| Gemma 4 E2B        | 1.5 GB        | 5 GB RAM | iPhone 12–14 standard — strong reasoning       |
| Qwen3.5 4B         | 2.5 GB        | 6 GB RAM | iPhone 15 Pro and newer                        |
| Gemma 4 E4B        | 5.0 GB        | 7 GB RAM | iPhone 15 Pro / 16 Pro / 17 Pro only           |

All models run at similar speed relative to their size. The larger models give more accurate and nuanced responses. Qwen3.5 2B and 4B are vision-capable — they handle both text and image requests in a single download. Qwen3.5 0.8B and Gemma models are text-only.

:::note
Models that require more RAM than your device has are shown in the catalog but are **disabled** with an explanation. You cannot download or load them.
:::

---

## Downloading a Model

1. **Open LucidPal for the first time** — the Model Download screen appears automatically.
2. **Check the recommended model** — the app selects the best model for your device RAM. You can switch to the other model if you prefer.
3. **Tap Download** — the download runs in the background. You can lock your screen — it continues automatically.
4. **Start chatting** — once the download completes, LucidPal loads the model and you're ready to go.

:::note
Wi-Fi is required. Downloads are blocked on cellular to protect your data plan. The models are between 0.51 GB and 5.0 GB.
:::

### During a download

While a download is in progress, a full-screen overlay shows the progress ring and model name. Navigation to other tabs is temporarily disabled — tap **Cancel** on the overlay if you want to stop the download.

### Background downloads

LucidPal uses iOS background transfer sessions, so the download continues even when the app is suspended or the screen is locked. If the app is terminated while a download is in progress, iOS resumes the transfer automatically when you reopen the app.

### Resuming interrupted downloads

If your WiFi drops mid-download, LucidPal saves resume data automatically. The next time you tap **Retry**, the download picks up from where it stopped — it does not restart from 0%. If the resume data becomes stale or corrupt, the app detects this and restarts cleanly.

### Integrity check

Every download is verified against a SHA-256 checksum sourced from HuggingFace LFS metadata. If the file is corrupt, LucidPal deletes it and retries automatically (up to 2 times). You will see a **Retry** button if all automatic retries fail.

---

## Recommended Model

The app selects a recommended model based on the physical RAM of your iPhone:

| Device RAM | Chip    | Recommended model |
| ---------- | ------- | ----------------- |
| 7 GB+      | Pro     | Gemma 4 E4B       |
| 5 GB+      | Any     | Gemma 4 E2B       |
| Less than 5 GB | Any | Qwen3.5 0.8B      |

Models that require more RAM or a Pro chip than your device has are shown in the catalog but are disabled for download. They remain visible so you can see what is available when upgrading to a newer device.

---

## Switching Models

Go to [**Settings**](./settings) → **Model** to switch between models. The new model loads the next time you start a conversation.

---

## Storage

Models are stored in the app's **Documents** folder (`/var/mobile/Containers/Data/Application/.../Documents/`). This folder is accessible via the **Files** app under **On My iPhone → LucidPal**.

Deleting the app also removes all downloaded model files.

### Freeing up space

To delete a downloaded model without uninstalling the app:

1. Go to [**Settings**](./settings) → **Model**.
2. Tap the model you want to remove.
3. Tap **Delete Model**.

The model file is removed immediately. You can re-download it at any time.

---

## Integrated Vision Models

**Qwen3.5 2B** and **Qwen3.5 4B** can read and describe images in addition to handling calendar requests — no separate vision model file is required. See [Vision & Photos](./vision-photos) for how to attach and analyze images.

When you select a vision-capable model, a **Vision** badge appears next to its name.

- One file covers everything — text chat, calendar operations, and image understanding.
- Vision features (such as reading a screenshot of an event invitation) are available immediately after the download completes.

Qwen3.5 0.8B and the Gemma 4 family are text-only models and do not support image input.

---

## Thinking Mode

**Qwen3.5** models support a **Thinking** mode where the AI reasons through your request before answering. This improves accuracy for complex calendar operations.

Toggle it per-chat via the brain icon (🧠) in the chat toolbar — this button only appears when a Qwen3.5 model is active. Gemma 4 models do not support Thinking mode and the toggle is hidden when they are loaded.

When enabled, you can tap the **Thinking** disclosure in any assistant reply to see the reasoning steps.

Thinking mode uses slightly more processing time but produces better results for multi-step calendar requests like:

> "Schedule a 2-hour block every Tuesday this month, but skip the week of March 10th"