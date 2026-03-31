---
sidebar_position: 9
---

# Voice Input

Using your voice to send messages in LucidPal.

LucidPal transcribes speech entirely on-device using **WhisperKit** (OpenAI Whisper tiny model). No audio is ever sent to a server.

---

## Recording a Message

1. Tap the **microphone** button in the input bar.
2. Speak your message.
3. LucidPal shows a live transcript as it processes your audio.
4. Tap **Send** to confirm, or **Cancel** to discard.

If **Auto-send** is enabled in Settings, the message sends automatically once transcription completes.

---

## Auto-Send

Enable **Settings → Voice → Auto-send after speech** to have LucidPal send the transcribed message without requiring you to tap Send.

---

## AirPods Auto-Voice

When AirPods (or compatible wireless headphones) are connected, you can enable **Settings → Voice → Auto-voice with AirPods**. With this on:

- Opening a chat automatically activates the microphone.
- An **Auto-listening** banner appears at the top of the screen.
- A 30-second silence timeout stops recording automatically if no speech is detected.

:::note
Auto-voice only activates when AirPods are the active audio output route. Switching to the iPhone's built-in speaker stops auto-voice.
:::

---

## Speech Model

LucidPal uses the **Whisper tiny** model for transcription. It is downloaded once when you first use the microphone and stored locally. After that, transcription works fully offline.

| Property     | Value                     |
| ------------ | ------------------------- |
| Model        | openai/whisper-tiny       |
| Language     | Auto-detected             |
| Audio format | 16 kHz mono WAV           |
| Silence timeout | 30 seconds            |

---

## Permissions

LucidPal requests microphone access the first time you tap the mic button. You can manage this in:

**iOS Settings → Privacy & Security → Microphone → LucidPal**

The app works fully without microphone access — just type your messages instead.
