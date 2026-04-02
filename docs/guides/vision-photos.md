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

**Qwen3.5 Vision 4B** is the recommended choice for most users. It is an *integrated* model — a single 2.5 GB file that covers all text requests (calendar, notes, habits) and all vision requests. There is no need to download anything else.

When a separate text model (e.g. Qwen3.5 2B) is active and a standalone vision model is also downloaded, LucidPal automatically switches to the vision model when it detects an image attachment, then switches back for text-only messages.

:::note
Integrated models show an **Integrated** badge in Settings. Separate vision models show a **Vision** badge.
:::

---

## Vision Settings

Go to [**Settings**](./settings) → **Vision** to control vision behaviour.

### Vision Toggle

A single **Vision** toggle (under the Vision section header) enables or disables photo attachment processing:

- **On** — photo attachments trigger the vision model. The paperclip icon is active in chat.
- **Off** — only text inference runs. Images cannot be attached. Use this if you want to conserve RAM or only use a text model.

### Vision Model Selection

Under [**Settings**](./settings) → **Vision Model**, you can:

- **Select which vision model is active** — tap any downloaded model to make it the active vision model
- **Download a new vision model** — tap **Download Vision Models** to browse available options
- **Delete a model** — swipe left on any downloaded model and tap Delete

If you select an integrated model here, it also becomes your active text model — there is no separate text model needed.

---

## Limitations

| Limitation | Detail |
|---|---|
| **Model must be downloaded first** | Vision only works when a vision or integrated model is downloaded and selected. The toggle is disabled until then. |
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
