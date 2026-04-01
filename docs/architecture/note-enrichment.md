---
sidebar_position: 6
---

# Note Enrichment

Technical reference for the on-device AI enrichment pipeline that runs after a note is saved.

## Overview

After a note is persisted, `NoteEnrichmentService` asynchronously processes it through the on-device LLM to produce three structured outputs:

- **Summary** — one-line description, ≤100 characters
- **Action items** — extracted to-dos as a string array
- **Category** — one of: `idea`, `task`, `journal`, `health`, `goal`, `memory`, `finance`, `other`

No note content is ever sent to a remote server. All inference runs locally via llama.cpp.

## Pipeline

```
Note saved (Core Data)
  └─▶ NoteEnrichmentService.enqueue(noteID)
        └─▶ pendingIDs.insert(noteID)          // deduplication guard
              └─▶ waitForLLM()                 // yield until model is free
                    └─▶ generate(prompt)       // llama.cpp inference
                          └─▶ parseResult()   // decode JSON from output
                                └─▶ save enriched fields to Core Data
```

### Step-by-step

| Step | Method | Notes |
|------|--------|-------|
| Enqueue | `enqueue(noteID:)` | Skips if ID is in `pendingIDs` or `permanentlyFailedIDs` |
| Wait | `waitForLLM()` | Async/await; suspends until `currentlyProcessingID == nil` |
| Generate | `generate(note:)` | Calls llama.cpp with `maxNewTokens: 256` |
| Parse | `parseResult(_:)` | Decodes JSON; falls back to `other` on invalid category |
| Persist | Core Data write | Updates `note.aiSummary`, `note.aiActionItems`, `note.aiCategory` |

## LLM Output Schema

The model is instructed to return strict JSON. No prose, no markdown fences.

```json
{
  "summary": "One-line summary of the note (≤100 chars)",
  "actionItems": ["Do X", "Follow up on Y"],
  "category": "idea|task|journal|health|goal|memory|finance|other"
}
```

If the model returns malformed JSON or an unrecognised category, `parseResult` applies safe defaults:
- `summary` → empty string (enrichment re-attempted is blocked; note appears without summary)
- `actionItems` → `[]`
- `category` → `"other"`

## Key Design Decisions

### `permanentlyFailedIDs`

A `Set<UUID>` that records notes for which enrichment failed (malformed output, model crash, token budget exceeded). Once an ID is added, it is never re-enqueued. This prevents infinite retry loops on pathological note content.

### Deduplication via `pendingIDs` + `currentlyProcessingID`

- `pendingIDs: Set<UUID>` — notes queued but not yet running
- `currentlyProcessingID: UUID?` — the note currently in inference

`enqueue` checks both sets before inserting, so rapid saves of the same note (e.g. autosave) do not queue duplicate enrichment jobs.

### `maxNewTokens: 256`

Capped at 256 tokens. The JSON schema is compact; 256 tokens is sufficient for all valid outputs and prevents runaway generation on adversarial input.

### `@MainActor` isolation

`NoteEnrichmentService` is `@MainActor`-isolated. Core Data writes happen on the main context, avoiding concurrency violations. LLM inference is dispatched to a background `LlamaActor`; only the final result crosses back to the main actor.

## Integration Points

| Component | Role |
|-----------|------|
| `NoteEnrichmentService` | Orchestrates the pipeline |
| `LlamaActor` | Manages llama.cpp model lifecycle; shared with chat |
| `NoteStore` | Calls `enqueue` after `saveNote()` |
| `NoteDetailView` | Reads `aiSummary`, `aiActionItems`, `aiCategory` from Core Data |
| `NotesListView` | Reads `aiCategory` to render category chip and filter |

## Adding a New Category

1. Add the raw value to the `NoteCategory` enum in `NoteCategory.swift`.
2. Update the prompt template in `NoteEnrichmentService` to include the new value in the schema description.
3. Add the display label and icon to `NoteCategory+UI.swift`.
4. Update `parseResult` if the new value requires special handling.
