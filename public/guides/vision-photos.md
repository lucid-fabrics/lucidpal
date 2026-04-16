---
sidebar_position: 10
---

# Vision & Photo Analysis

Attach photos, screenshots, and documents to any chat message — LucidPal describes them, reads text from them, and answers questions, entirely on your device.

---

## What Vision Analysis Does

Vision lets the AI "see" images you attach to a message. You can:

- **Describe a photo** — "What's in this picture?"
- **Read text from a screenshot** — parse event invitations, menus, receipts, or handwritten notes
- **Analyse a document image** — extract key details from a scanned page or photo of a whiteboard
- **Answer questions about an image** — "How many items are on this receipt?" or "What date is on this flyer?"

The model processes the visual content and combines it with your text question to give a single, unified reply — the same way the text model handles a calendar request.

---

## How to Attach a Photo

1. **Open a chat session** in LucidPal.
2. Tap the **paperclip / attachment icon** next to the text input field.
3. Choose **Photo Library** to pick an existing photo, or **Camera** to take one now.
4. Select your image — a thumbnail preview appears in the input bar.
5. Type your question (optional — you can send with just the image).
6. **Send** the message.

The vision model processes the image, then the full response appears in the chat bubble.

:::note
Only one image can be attached per message. To ask about multiple images, send separate messages.
:::

---

## What the Model Sees

Before the image reaches the model, LucidPal's `VisionImageProcessor` automatically:

1. **Resizes** the image so its longest side is at most **896 px**, preserving aspect ratio
2. **Compresses** it to JPEG at **0.8 quality** — enough fidelity for accurate analysis, small enough to run quickly
3. **Passes the JPEG** to the vision model's CLIP encoder for embedding

A separate 224 px thumbnail is generated for the chat bubble preview — that smaller version is never sent to the model.

This means the model sees a clean, reasonably detailed version of your image — fine for reading printed text, identifying objects, and describing scenes. Very small text (e.g., 6-pt footnotes) or highly detailed charts may not be fully legible.

---

## The Qwen3.5 Vision 4B Model

LucidPal offers two ways to get vision capability:

| Setup | How it works |
|---|---|
| **Integrated model** (Qwen3.5 Vision 4B) | One download handles both text chat and image analysis — no second model needed |
| **Separate vision model** | A dedicated vision GGUF loaded alongside your text model |

All four catalog models are *integrated* — a single GGUF file covers both text and vision. Vision is enabled automatically once a model is downloaded; there is no toggle to turn on.

:::note
Integrated models show an **Integrated** badge in the Model Catalog. When the mmproj (vision projector) file is not yet downloaded, LucidPal downloads it automatically the first time a model loads.
:::

---

## Model Catalog

Open **Settings → AI Model → Browse Model Catalog** to download or manage models. All listed models support vision:

| Model | Size | Min RAM |
|-------|------|---------|
| Gemma 4 E2B | 1.5 GB | 3 GB |
| Qwen3.5 2B | 1.3 GB | 3 GB |
| Qwen3.5 4B | 2.5 GB | 5 GB |
| Gemma 4 E4B | 5.0 GB | 6 GB |

Swipe left on a downloaded model to delete it.

---

## Limitations

| Limitation | Detail |
|---|---|
| **Model must be downloaded first** | Vision only works when a model is downloaded. Open Settings → AI Model → Browse Model Catalog to download one. |
| **RAM requirement** | Qwen3.5 Vision 4B requires ~5 GB of available RAM — iPhone 14 Pro, 15, or 16 series recommended. |
| **One image per message** | Multiple attachments in a single message are not supported. |
| **Image size cap** | Images are auto-downscaled so their longest side is at most 896 px (aspect ratio preserved). Very large originals lose no important detail, but microscopic text may not be legible. |
| **Image types** | Works best with clear, well-lit photos. Blurry, very dark, or heavily compressed images produce less accurate results. |
| **No video** | Only still images (JPEG, PNG, HEIF) are supported. |
| **No PDF pages** | For PDF documents, use the [Document Summarization](./document-summarization) feature instead. |

---

## Privacy

All image processing is **100% on-device**. Your photos are:

- Resized and encoded locally by `VisionImageProcessor`
- Stored temporarily in the app's private temp directory during inference
- Passed only to the local vision model — never uploaded to any server
- Removed from temp storage after the response is generated

See the [Privacy guide](./privacy) for the full data table.
