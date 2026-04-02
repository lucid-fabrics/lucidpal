---
sidebar_position: 6
---

# Note Enrichment

How LucidPal asynchronously enriches saved notes with AI-generated summaries, action items, and categories.

## What It Does

`NoteEnrichmentService` runs in the background after a note is saved. It sends the note body to the on-device LLM and writes three fields back to the note:

| Field           | Type           | Description                                                              |
| --------------- | -------------- | ------------------------------------------------------------------------ |
| `aiSummary`     | `String?`      | One-sentence factual summary (≤100 chars)                                |
| `aiActionItems` | `[String]`     | Explicit to-dos extracted from the note body                             |
| `aiCategory`    | `NoteCategory` | One of: `idea task journal health goal memory finance other`             |

Enrichment is skipped if `aiSummary` is already set (note already enriched) or if the note body is empty. No note content is sent to a remote server — all inference runs locally via llama.cpp.

## Enrichment Pipeline

```
Note saved
      ↓
NoteEnrichmentService.enqueue(noteID)
      ↓
Deduplication check
(queue + in-flight ID + permanentlyFailedIDs)
      ↓
processNext() — serial queue, one note at a time
      ↓
waitForLLM() — polls isLoaded && !isGenerating (up to 30 s, 60 × 500 ms)
      ↓
enrichmentPrompt(for:) — builds prompt with note title + body (≤600 chars)
      ↓
llmService.generate() → AsyncThrowingStream<String>
(thinkingEnabled: false, modelRole: .text, maxNewTokens: 256)
      ↓
Accumulate tokens → full response string
      ↓
parseResult(from:) — strip code fences, decode JSON
      ↓
applyEnrichment(to:from:) — write aiSummary/aiActionItems/aiCategory
      ↓
notesStore.save(note)
      ↓
onNoteUpdated?() — callback refreshes UI on @MainActor
```

## Prompt Format

The LLM is instructed to return **only valid JSON** — no markdown, no explanation:

```swift
let systemPrompt = "You are a note analyzer. Respond only with valid JSON, no explanation."
```

User message sent to the model:

```
Analyze this note. Respond with JSON only — no markdown, no explanation.

<note_title>Meeting notes</note_title>
<note_body>... first 600 chars of note body ...</note_body>

JSON format (all fields required):
{"summary":"one sentence max 100 chars","actionItems":["task1","task2"],"category":"idea|task|journal|health|goal|memory|finance|other"}

Rules:
- summary: factual one-liner, ≤100 chars
- actionItems: explicit to-dos only, empty array [] if none
- category: exactly one from the list
```

## JSON Parsing

`parseResult(from:)` applies two strategies in order:

1. **Direct decode** — strip markdown code fences (` ```…``` `) if present, then attempt `JSONDecoder` on the cleaned string.
2. **Extraction fallback** — locate the outermost `{...}` substring and decode that.

This handles models that wrap responses in markdown code fences (` ```json ... ``` `).

```swift
private struct RawResult: Decodable {
    let summary: String
    let actionItems: [String]
    let category: String
}
```

Decoded values are sanitised before writing to the note:

- `aiSummary` — capped at 200 chars; set to `nil` if the string is empty
- `aiActionItems` — at most 10 items, each capped at 200 chars
- `aiCategory` — mapped via `NoteCategory(rawValue:)`, falls back to `.other`

## Error Handling and Retry Prevention

| Situation                        | Behaviour                                                              |
| -------------------------------- | ---------------------------------------------------------------------- |
| LLM not ready after 30 s         | Skip note; debug log; note stays unenriched                            |
| `llmService.generate()` throws   | Skip note; error log; note stays unenriched                            |
| JSON parse fails                 | Add `noteID` to `permanentlyFailedIDs`; note never re-enqueued         |
| Note already has `aiSummary`     | `enrichNote(id:)` returns early — no LLM call made                    |
| Duplicate `enqueue()` call       | Silently ignored (checked against pending queue, in-flight ID, failed set) |

:::note
`permanentlyFailedIDs` is in-memory only. It resets on app restart, giving one retry opportunity per session for notes with malformed LLM responses.
:::

## Actor and Concurrency Model

`NoteEnrichmentService` is annotated `@MainActor` — all mutations to `pendingIDs`, `currentlyProcessingID`, and `permanentlyFailedIDs` happen on the main thread.

Long-running work (LLM polling and token streaming) runs inside a `Task {}` that inherits `@MainActor` isolation but **suspends** at every `await` point, so the main thread is never blocked:

```swift
Task {
    await enrichNote(id: id)       // suspends during waitForLLM() and generate()
    currentlyProcessingID = nil
    processNext()                  // pick next note from queue
}
```

The queue is strictly serial: `processNext()` only starts a new `Task` when `currentlyProcessingID == nil`.

## Integration Points

| Dependency           | Role                                                                          |
| -------------------- | ----------------------------------------------------------------------------- |
| `LLMServiceProtocol` | Provides `isLoaded`, `isGenerating`, and `generate()` streaming               |
| `NotesStoreProtocol` | Source of truth for note lookup; target of `save(_:)` after enrichment        |
| `NotesListViewModel` | Calls `enqueue()` after a note is saved; receives `onNoteUpdated` to refresh UI |

`NoteEnrichmentService` has no protocol of its own — it is injected as a concrete type directly into `NotesListViewModel`.

:::note
`NoteEnrichmentService` shares the same LLM instance used for chat. Enrichment waits for the model to be idle (`!isGenerating`) rather than interrupting an active chat stream.
:::
