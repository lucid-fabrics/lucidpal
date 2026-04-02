---
sidebar_position: 9
---

# Voice Input

Using your voice to send messages in LucidPal.

LucidPal transcribes speech entirely on-device using **WhisperKit** (OpenAI Whisper tiny model). No audio is ever sent to a server.

---

## Recording a Message

1. Tap the **microphone** button in the input bar.
2. A fullscreen overlay appears with a **pulsing mic** animation — speak your message.
3. Tap the **stop** button (or wait for the 30-second timeout) to finish recording.
4. The overlay switches to an animated **waveform** while WhisperKit transcribes your audio.
5. The transcript appears. Tap ✓ to confirm, or ✕ to discard.

The confirm and cancel buttons are hidden during transcription and reappear once the transcript is ready.

If **Auto-send** is enabled in [Settings](./settings#inference), the message sends automatically once transcription completes.

---

## Auto-Send

Enable [**Settings**](./settings#inference) → **Auto-send after speech** to have LucidPal send the transcribed message without requiring you to tap Send.

---

## AirPods Auto-Voice

When AirPods (or compatible wireless headphones) are connected, you can enable [**Settings**](./settings#inference) → **AirPods auto-voice**. With this on:

- The microphone activates automatically as soon as AirPods become the active audio route.
- An **Auto-listening** banner appears at the top of the screen.
- A 30-second maximum recording duration stops recording automatically.
- If an audio interruption (e.g. a phone call) ends while AirPods are still connected, auto-voice resumes automatically.

:::note
Auto-voice only activates when AirPods are the active audio output route. Switching to the iPhone's built-in speaker stops auto-voice immediately.
:::

---

## Speech Model

LucidPal uses the **Whisper tiny** model for transcription. It is downloaded once when you first use the microphone and stored locally. After that, transcription works fully offline.

| Property     | Value                     |
| ------------ | ------------------------- |
| Model        | openai/whisper-tiny       |
| Language     | Auto-detected             |
| Audio format | 16 kHz mono WAV           |
| Max recording duration | 30 seconds       |

---

## Permissions

LucidPal requests microphone access the first time you tap the mic button. You can manage this in:

**iOS Settings → Privacy & Security → Microphone → LucidPal**

The app works fully without microphone access — just type your messages instead.
