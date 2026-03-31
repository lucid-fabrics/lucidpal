---
sidebar_position: 4
---

# AI Models

Choosing and downloading the right model for your iPhone.

LucidPal runs an AI model entirely on your device. On first launch, you'll be prompted to download one. The app recommends the best model for your iPhone automatically.

## Available Models

### Text Models

| Model        | Download size | Min RAM  | Best for                             |
| ------------ | ------------- | -------- | ------------------------------------ |
| Qwen3.5 0.8B | 0.51 GB       | 2 GB RAM | Older iPhones with limited RAM       |
| Qwen3.5 2B   | 1.2 GB        | 3 GB RAM | iPhone 12 / 13 — recommended default |
| Qwen3.5 4B   | 2.5 GB        | 5 GB RAM | iPhone 14 Pro / 15 / 16 and newer    |

All three models run at similar speed relative to their size — the 4B model gives more accurate and nuanced responses.

### Vision Model

| Model              | Download size      | Min RAM  | Best for                          |
| ------------------ | ------------------ | -------- | --------------------------------- |
| Qwen3.5 Vision 4B  | 2.5 GB + 0.5 GB projector | 5 GB RAM | Analyzing photos and screenshots |

The Vision model is an **integrated** model — it handles both text and image understanding with a single model load. When selected in **Settings → Vision**, it replaces the text model rather than loading alongside it.

:::note
The Vision model requires a second file (the multimodal projector, `mmproj`) which is downloaded automatically alongside the main model.
:::

---

## Downloading a Model

1. **Open LucidPal for the first time** — the Model Download screen appears automatically.
2. **Check the recommended model** — the app selects the best model for your device RAM. You can switch to another if you prefer.
3. **Tap Download** — the download runs in the background. You can lock your screen — it continues automatically.
4. **Start chatting** — once the download completes, LucidPal loads the model and you're ready to go.

:::note
Wi-Fi is strongly recommended. The models are between 0.51 GB and 2.5 GB.
:::

After downloading, LucidPal verifies the file's **SHA-256 checksum** against the published hash from HuggingFace. If the checksum doesn't match (e.g. a corrupted download), the app automatically retries up to two times before reporting an error.

---

## Switching Models

Go to **Settings → AI Model** to switch between models. The new model loads the next time you start a conversation.

---

## Storage

Models are stored in the app's local storage on your device. Deleting the app also removes the downloaded model file.

---

## Context Windows & TurboQuant

LucidPal is built against a fork of llama.cpp that includes **TurboQuant** — a KV cache compression technique from Google (ICLR 2026). It compresses the AI's working memory by ~5× using a mathematically lossless rotation followed by 4-bit quantization, all running on the iPhone's GPU via Metal.

In plain terms: it lets your iPhone hold much longer conversations without running out of RAM. The context window (how much the AI can "see" at once) scales with your device:

| Device | Context window |
|--------|---------------|
| iPhone 12, 13 (4 GB) | 4,096 tokens (~15 pages) |
| iPhone 13 non-Pro (6 GB) | 8,192 tokens (~30 pages) |
| iPhone 13 Pro, 14, 15 (6 GB) | 16,384 tokens (~60 pages) |
| iPhone 15 Pro, 16, 17 (8 GB) | 32,768 tokens (~120 pages) |

:::note
Without TurboQuant, the 16K and 32K windows would exceed available RAM entirely. The compression has no measurable quality impact on the 0.8B–4B model sizes LucidPal uses.
:::

[Technical deep-dive → Architecture: TurboQuant](/architecture/turboquant)

---

## Thinking Mode

Qwen3.5 models support a **Thinking** mode where the AI reasons through your request before answering. This improves accuracy for complex calendar operations.

Toggle it in **Settings → Thinking Mode**. When enabled, you can tap the **Thinking** disclosure in any assistant reply to see the reasoning steps.

Thinking mode uses slightly more processing time but produces better results for multi-step calendar requests like:

> "Schedule a 2-hour block every Tuesday this month, but skip the week of March 10th"

---

## Advanced Settings

Go to **Settings → Advanced** to tune inference behavior:

| Setting            | Default | Description                                                   |
| ------------------ | ------- | ------------------------------------------------------------- |
| Temperature        | 0.35    | How creative the response is. Lower = more deterministic.     |
| Max Response Tokens | 768    | Maximum number of tokens generated per response.              |
| Generation Timeout | 90 s    | Cancel and preserve partial response if generation stalls.    |
| Context Size       | Auto    | How many tokens the model can "see". Set automatically by RAM.|

:::note
The context size is set automatically based on your device's RAM. Manual overrides are capped to a RAM-safe maximum to prevent out-of-memory crashes.
:::
