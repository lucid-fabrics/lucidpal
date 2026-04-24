---
sidebar_position: 4
---

# AI Models

Download, manage, and switch between GGUF models that run entirely on-device via llama.cpp.

## Available Models

| Model | Download size | Min RAM | Capabilities |
| ----- | ------------- | ------- |-------------|
| **Qwen3.5 0.8B** | 0.51 GB | 2 GB | Text only — fastest, most limited context |
| **Qwen3.5 2B** | 1.2 GB | 3 GB | Text only — balanced speed and quality |
| **Qwen3.5 4B** | 2.5 GB | 5 GB | Text only — best quality on-device |
| **Qwen3.5 4B Vision** | 2.5 GB + mmproj | 5 GB | Text + photo analysis — single download, no separate vision model needed |

All four models support **Thinking mode** (Qwen3's `<think>...` reasoning blocks).

---

## Recommended Model

The app recommends a model automatically based on your device's physical RAM:

| Device RAM | Recommended model | Why |
|-----------|-------------------|-----|
| 2–3 GB | Qwen3.5 0.8B | Only model that fits |
| 3–5 GB | Qwen3.5 2B | Best balance of speed and quality |
| 5 GB+ | Qwen3.5 4B | Full intelligence and longest context |

Models exceeding your device's RAM are hidden from the selection list.

---

## Downloading a Model

1. **Open LucidPal for the first time** — the Model Download screen appears automatically.
2. **Check the recommended model** — the app selects the best model for your device RAM. You can switch to a different model if you prefer.
3. **Tap Download** — the download runs in the background. You can lock your screen — it continues automatically.
4. **Start chatting** — once the download completes, LucidPal loads the model and you're ready to go.

:::note
Wi-Fi is required. Downloads are blocked on cellular to protect your data plan.
:::

### Background downloads

LucidPal uses iOS background transfer sessions, so the download continues even when the app is suspended or the screen is locked. If the app is terminated while a download is in progress, iOS resumes the transfer automatically when you reopen the app.

### Resuming interrupted downloads

If your WiFi drops mid-download, LucidPal saves resume data automatically. The next time you tap **Retry**, the download picks up from where it stopped — it does not restart from 0%. If the resume data becomes corrupt, the app detects this and restarts cleanly.

### Integrity check

Every download is verified against a SHA-256 checksum sourced from HuggingFace LFS metadata. If the file is corrupt, LucidPal deletes it and retries automatically (up to 2 times).

---

## Integrated Vision Models

**Qwen3.5 4B Vision** is an integrated model — it handles both text and images in a single download. When you select it:

- One file covers everything: text chat, calendar operations, and image understanding
- No separate vision model download required
- Vision features are available immediately after the single download completes

When you select an integrated model in onboarding or in **Settings → Text Model**, an **Integrated** badge appears next to its name. The app automatically hides text-only models of the same tier to avoid confusion.

---

## Switching Models

Go to **Settings → Text Model** to switch between downloaded models. The new model loads the next time you start a conversation.

---

## Vision Model (Separate Download)

If you use Qwen3.5 4B (text-only) as your main model, you can separately download the vision model in **Settings → Vision Model**. This lets you run the faster 4B text model and switch to vision only when needed.

The vision model requires:
- A separate **mmproj** file (vision projector, ~1.5 GB)
- The main vision GGUF file (~2.5 GB)

Both are downloaded together from the same screen.

---

## Context Window

Context window size is determined by your device's RAM:

| Device RAM | Max context | History kept |
|-----------|------------|-------------|
| < 6 GB | 4K tokens | ~20 messages |
| ≥ 6 GB | 8K tokens | ~50 messages |

You can reduce the context window in **Settings → Inference → Context Size** for more RAM headroom on very large models.

---

## Custom Models

Custom GGUF model support is planned for a future release.

---

## Deleting a Model

1. Go to **Settings → Text Model** (or **Vision Model**)
2. Tap the model you want to remove
3. Tap **Delete Model**

The file is removed immediately. You can re-download it at any time.

---

## Storage

Models are stored in the app's **Documents** folder accessible via the **Files** app under **On My iPhone → LucidPal**.

Deleting the app also removes all downloaded model files.