---
sidebar_position: 6
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
| Markdown (`.md`, `.markdown`) | Read directly |
| Rich Text (`.rtf`) | NSAttributedString parser |

---

## Attaching a Document

1. Open any chat session.
2. Tap the **paperclip** icon next to the input bar.
3. The system document picker opens — browse Files, iCloud Drive, or any connected provider.
4. Select a file. A **pill** (small badge showing the filename) appears above the input bar, confirming the attachment.
5. Type your question (optional) and send.

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
- **Maximum file size:** Large files are processed page-by-page; very long documents may be truncated to fit within the model's context window.
- **Scanned PDFs:** LucidPal uses on-device OCR to extract text from image-based PDFs. Accuracy depends on scan quality.
- **No persistent storage:** Attached documents are processed for the current message only. They are not saved to your notes or any persistent store.
- **Multiple attachments:** You can attach several files to a single message. Each appears as its own pill above the input bar. Tap **×** on a pill to remove that file before sending.
:::

---

## Privacy

Document content is processed locally using PDFKit and Apple's Vision framework. No file content leaves your device.

<details>
<summary>How does OCR work on scanned PDFs?</summary>

When PDFKit finds no selectable text in a PDF page, LucidPal falls back to Apple's Vision framework to run on-device optical character recognition. The recognized text is then passed to the language model. This happens automatically — you don't need to do anything differently.

</details>
