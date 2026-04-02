---
sidebar_position: 4
---

# AI Models

Choosing and downloading the right model for your iPhone.

LucidPal runs an AI model entirely on your device. On first launch, you'll be prompted to download one. The app recommends the best model for your iPhone automatically.

## Available Models

| Model              | Download size | Min RAM  | Best for                             |
| ------------------ | ------------- | -------- | ------------------------------------ |
| Qwen3.5 0.8B       | 0.51 GB       | 2 GB RAM | Older iPhones with limited RAM       |
| Qwen3.5 2B         | 1.2 GB        | 3 GB RAM | iPhone 12 / 13 — recommended default |
| Qwen3.5 4B         | 2.5 GB        | 5 GB RAM | iPhone 14 Pro / 15 / 16 and newer    |
| Qwen3.5 Vision 4B  | 2.5 GB        | 5 GB RAM | Image understanding + text (integrated) |

All four models run at similar speed relative to their size — the 4B models give more accurate and nuanced responses. The Vision 4B model handles both text and image requests in a single download.

---

## Downloading a Model

1. **Open LucidPal for the first time** — the Model Download screen appears automatically.
2. **Check the recommended model** — the app selects the best model for your device RAM. You can switch to the other model if you prefer.
3. **Tap Download** — the download runs in the background. You can lock your screen — it continues automatically.
4. **Start chatting** — once the download completes, LucidPal loads the model and you're ready to go.

:::note
Wi-Fi is required. Downloads are blocked on cellular to protect your data plan. The models are between 0.51 GB and 2.5 GB.
:::

### Background downloads

LucidPal uses iOS background transfer sessions, so the download continues even when the app is suspended or the screen is locked. If the app is terminated while a download is in progress, iOS resumes the transfer automatically when you reopen the app.

### Resuming interrupted downloads

If your WiFi drops mid-download, LucidPal saves resume data automatically. The next time you tap **Retry**, the download picks up from where it stopped — it does not restart from 0%. If the resume data becomes stale or corrupt, the app detects this and restarts cleanly.

### Integrity check

Every download is verified against a SHA-256 checksum sourced from HuggingFace LFS metadata. If the file is corrupt, LucidPal deletes it and retries automatically (up to 2 times). You will see a **Retry** button if all automatic retries fail.

---

## Recommended Model

The app selects a recommended model based on the physical RAM of your iPhone:

| Device RAM | Recommended model |
| ---------- | ----------------- |
| 5 GB or more | Qwen3.5 4B |
| 3–4 GB | Qwen3.5 2B |
| Less than 3 GB | Qwen3.5 0.8B |

Models that exceed your device's RAM threshold are hidden from the selection list — only models your device can run are shown.

---

## Switching Models

Go to [**Settings**](./settings) → **Text Model** to switch between models. The new model loads the next time you start a conversation.

---

## Storage

Models are stored in the app's **Documents** folder (`/var/mobile/Containers/Data/Application/.../Documents/`). This folder is accessible via the **Files** app under **On My iPhone → LucidPal**.

Deleting the app also removes all downloaded model files.

### Freeing up space

To delete a downloaded model without uninstalling the app:

1. Go to [**Settings**](./settings) → **Text Model**.
2. Tap the model you want to remove.
3. Tap **Delete Model**.

The model file is removed immediately. You can re-download it at any time.

---

## Integrated Vision Models

Some models combine text and vision capabilities in a single download. **Qwen3.5 Vision 4B** is one example — it can read and describe images in addition to handling calendar requests, without requiring a separate vision model file. See [Vision & Photos](./vision-photos) for how to attach and analyze images.

When you select an integrated model in the onboarding carousel or in [**Settings**](./settings) → **Text Model**, an **Integrated** badge appears next to its name. The app automatically hides any text-only models of the same tier to avoid confusion — there is no need to download both.

If you choose an integrated model:

- One file covers everything — text chat, calendar operations, and image understanding.
- You do not need to download a separate vision model.
- Vision features (such as reading a screenshot of an event invitation) are available immediately after the single download completes.

---

## Thinking Mode

Qwen3.5 models support a **Thinking** mode where the AI reasons through your request before answering. This improves accuracy for complex calendar operations.

Toggle it in [**Settings**](./settings) → **Inference → Advanced** (or per-chat via the brain icon in the chat toolbar). When enabled, you can tap the **Thinking** disclosure in any assistant reply to see the reasoning steps.

Thinking mode uses slightly more processing time but produces better results for multi-step calendar requests like:

> "Schedule a 2-hour block every Tuesday this month, but skip the week of March 10th"

<details>
<summary>For developers</summary>

See [architecture/model-download](../architecture/model-download) for how model selection, background downloads, integrity checks, and resume logic are implemented.

</details>
