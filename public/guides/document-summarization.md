---
sidebar_position: 12
---

# Document & File Summarization

Attach PDFs and text files to any chat message so the AI can read and summarize them.

---

## Overview

LucidPal can process documents entirely on-device. Attach a PDF or plain-text file to your message, and the AI extracts the text and answers questions about it — without uploading your files anywhere.

| Supported format | How text is extracted |
|---|---|
| PDF (`.pdf`) | PDFKit (text layer) + Vision OCR fallback for scans |
| Plain text (`.txt`) | Read directly |
| Markdown (`.md`, `.markdown`) | Read directly — open via Files app and use **Share → LucidPal** |
| Rich Text (`.rtf`) | NSAttributedString parser |

---

## Attaching a Document

Document attachment works in both **chat sessions** and **agent tasks** — see [In Agent Mode](#in-agent-mode) below for the agent-specific flow.

1. Open any chat session.
2. Tap the **paperclip** icon next to the input bar.
3. The system document picker opens — browse Files, iCloud Drive, or any connected provider.
4. Select a file. A **pill** (small badge showing the filename) appears above the input bar, confirming the attachment.
5. Type your question (optional) and send. The send button is enabled even without text when a document is attached.

:::tip
You don't need to type anything. Simply attach a file and send — the AI will summarize the document automatically.
:::

---

## What You Can Ask

Once a document is attached, the AI has access to its full text for that message. Example prompts:

- "Summarize this document"
- "What are the key points in this contract?"
- "List all dates mentioned in this report"
- "Does this PDF mention a refund policy?"

---

## Limitations

:::note
- **Text limit:** Document text is capped at 8,000 characters. Pages are read in order until the limit is reached; content beyond that is not sent to the model.
- **Scanned PDFs:** LucidPal uses on-device OCR to extract text from image-based PDFs. Accuracy depends on scan quality.
- **No persistent storage:** Attached documents are processed for the current message only. They are not saved to your notes or any persistent store.
- **One file per tap:** The document picker is single-select. Tap the paperclip again to add another file; each appears as its own pill above the input bar. Tap **×** on a pill to remove it before sending.
:::

---

## In Agent Mode

The doc icon in the Agent Mode input bar opens the same system document picker. Key differences from chat:

| | Chat | Agent Mode |
|---|---|---|
| Entry point | Paperclip icon in chat input | Doc icon in Agent sheet input bar |
| Max files per submission | Unlimited (one per tap) | 3 files |
| Characters extracted per file | 8,000 | 8,000 |
| Attachments cleared after send | Yes | Yes |

The agent can combine document content with tool calls in the same task. For example:

- "Add the action items from this PDF to my notes"
- "Does this contract mention a deadline this month? Check my calendar."
- "Summarize these three reports and email me the highlights"

---

## Privacy

Document content is processed locally using PDFKit and Apple's Vision framework. No file content leaves your device.

<details>
<summary>How does OCR work on scanned PDFs?</summary>

When PDFKit finds no selectable text in a PDF page, LucidPal falls back to Apple's Vision framework to run on-device optical character recognition. The recognized text is then passed to the language model. This happens automatically — you don't need to do anything differently.

</details>
