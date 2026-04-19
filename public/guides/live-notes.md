---
sidebar_position: 10
---

# Live Notes

Record meetings, conversations, and ideas — and get an AI-generated summary automatically.

---

## Overview

Live Notes captures live audio, transcribes it in real time with **speaker diarization** (multiple speakers identified and color-coded), then saves the transcript as a searchable note enriched with an AI summary and action items.

This feature requires a **Pro subscription**.

---

## Accessing Live Notes

### From the Notes tab
1. Open the **Notes** tab.
2. Tap the **waveform mic** button (🎙) in the toolbar (top-right).
3. Grant **microphone access** when prompted.

### From the Agent screen
Live Notes can also be started by voice or text through the Agent:

1. Open the **Agent** tab.
2. Say or type a phrase like:
   - *"Start a Live Notes session"*
   - *"Live notes"*
   - *"Transcribe"*
   - *"Record this meeting"*
   - *"Record this call"*
   - *"Start recording"*
   - *"Capture this meeting"*
   - *"Meeting notes"*
   - *"Take a voice note"*
3. If you have a Pro subscription, the Live Notes sheet opens immediately. If not, an upgrade prompt is shown instead.

The Agent screen also shows a **"Live Notes"** card in the ability drawer for one-tap access.

---

## Recording States

| State | Indicator | What it means |
|-------|-----------|---------------|
| **Ready** | Microphone icon | Waiting to connect |
| **Connecting** | Spinner | Establishing the audio stream |
| **Recording** | Live transcript + amplitude bar | Capturing audio in real time |
| **Generating summary** | Spinner | Sending transcript to AI |
| **Reconnecting** | Orange banner + spinner | Briefly lost connection — attempting to reconnect (up to 3 tries at 1s, 2s, 4s intervals) |
| **Error** | Warning icon + message | Something went wrong — tap Dismiss |

---

## Live Transcript View

While recording, the screen shows:

- **Speaker bubbles** — each speaker gets a color-coded bubble. Speaker labels ("Speaker 1", "Speaker 2", etc.) appear above each segment.
- **Partial transcript** — the current spoken phrase appears at the bottom of the transcript in real time.
- **Mic amplitude bar** — a visual waveform shows your current audio input level.

The transcript scrolls automatically to keep the latest content visible.

---

## Stopping and Saving

Tap **Stop & Save** to end the recording. LucidPal:

1. Stops audio capture.
2. Sends the full transcript to the AI.
3. Generates a title, summary, and action items.
4. Saves everything as a note.

The note title is auto-generated from the content (or "Voice Note" if no title can be derived). You can rename it later in the note editor.

:::note
If no speech was detected, the recording is discarded and the screen returns to idle — nothing is saved.
:::

---

## What Gets Saved

| Field | Source |
|-------|--------|
| **Title** | AI-generated from transcript content, or "Voice Note" |
| **Body** | Full raw transcript (up to 50,000 characters) |
| **AI Summary** | Concise AI-generated recap |
| **Action Items** | Tasks and to-dos extracted from the transcript |
| **Source** | Marked as voice — note card shows a mic icon |

Open the saved note to see the **AI Insights** section with the summary and action items. Tap any action item to schedule it as a reminder.

---

## Speaker Diarization

Deepgram's streaming API detects and labels different speakers in real time. Each speaker is assigned a consistent color (indigo, teal, orange, pink) throughout the transcript. Speaker labels update automatically as new voices are detected.

---

## Monthly Limits

Live Notes tracks usage in **minutes per calendar month**:

| Plan | Monthly limit |
|------|--------------|
| Pro | 300 minutes (~5 hours) |
| Ultimate | 1,200 minutes (~20 hours) |

When the monthly limit is reached, the session endpoint returns an error and the recording cannot start until the next calendar month. Your remaining minutes are not shown in-app — plan accordingly.

---

## Requirements

| Requirement | Details |
|-------------|---------|
| **Subscription** | Pro or Ultimate — free tier cannot use Live Notes |
| **Microphone permission** | Required on first use. Enable in **Settings → Privacy & Security → Microphone → LucidPal** |
| **Internet connection** | Audio streams to Deepgram; summary generated via cloud AI |
| **Note storage** | Voice notes count toward your 500-note limit |

See the [Notes guide](./notes) for details on note storage limits.
