---
sidebar_position: 7
---

# System Prompt Builder

How LucidPal assembles the AI's system prompt from modular, permission-aware sections.

## Overview

`SystemPromptBuilder` collects an ordered list of `PromptSection` conformers, calls each one asynchronously, and joins non-nil results into the final system prompt string. It also doubles as the executor for all action blocks embedded in LLM responses (calendar, notes, contacts, habits, reminders, web search).

Adding a new tool capability requires only a new `PromptSection` conformer — `SystemPromptBuilder` itself never changes (Open/Closed Principle).

## The `PromptSection` Protocol

```swift
@MainActor
protocol PromptSection {
    /// Returns the prompt text for this section, or nil if inactive/disabled.
    func build() async -> String?
    /// False for sections excluded from the synthesis re-generation pass.
    var includedInSynthesis: Bool { get }
}

extension PromptSection {
    var includedInSynthesis: Bool { true }   // default: include in synthesis
}
```

Each section is responsible for its own gating — it returns `nil` when the feature is disabled or permission is denied, so no text is injected.

## Section Inventory

Sections are registered in this order in the production convenience initialiser:

| Order | Section | What it injects | Synthesis? |
|-------|---------|----------------|------------|
| 1 | `IdentityPromptSection` | "You are LucidPal…" — role, date, timezone, region, city | Yes |
| 2 | `TemplatePromptSection` | Active conversation template persona + addendum | Yes |
| 3 | `CalendarPromptSection` | Today's events, free slots, calendar tool instructions | Yes |
| 4 | `WebSearchPromptSection` | `[WEB_SEARCH:{...}]` tool instructions | **No** |
| 5 | `CrossAppContextSection` | Notes / Reminders / Mail context from `ContextService` | Yes |
| 6 | `NotesPromptSection` | Notes tool instructions (if permission granted) | Yes |
| 7 | `ContactsPromptSection` | Contacts tool instructions (if permission granted) | Yes |
| 8 | `HabitPromptSection` | Habit tracking tool instructions (if store present) | Yes |
| 9 | `ReminderPromptSection` | Reminder scheduling tool instructions | Yes |

`WebSearchPromptSection` sets `includedInSynthesis = false` so the model cannot recurse into another web search during the synthesis pass.

## Prompt Assembly

```swift
private func assemblePrompt(synthesisOnly: Bool) async -> String {
    var parts: [String] = []
    for section in sections {
        if synthesisOnly, !section.includedInSynthesis { continue }
        if let text = await section.build() { parts.append(text) }
    }
    return parts.joined(separator: " ")
}
```

`buildSystemPrompt()` calls `assemblePrompt(synthesisOnly: false)`.
`buildSynthesisPrompt()` calls `assemblePrompt(synthesisOnly: true)`, omitting web-search tool instructions so the model synthesises from search results rather than requesting another search.

## Full Message Structure

The assembled system prompt is the first input to `LLMService.generate()`:

```
┌─────────────────────────────────────────────────┐
│  System Prompt (built by SystemPromptBuilder)   │
│                                                 │
│  Identity → Template → Calendar → WebSearch →  │
│  CrossAppContext → Notes → Contacts →           │
│  Habits → Reminders                             │
├─────────────────────────────────────────────────┤
│  Conversation History  (trimmed to RAM limit)   │
│  [user] → [assistant] → [user] → …             │
├─────────────────────────────────────────────────┤
│  Current User Message                           │
└─────────────────────────────────────────────────┘
```

## Action Block Execution

After the model responds, `SystemPromptBuilder` parses and executes embedded action tags using regex matching. Each tag type follows the same pattern `[TAG:{json}]`:

| Tag | Regex constant | Executor |
|-----|---------------|---------|
| `[CALENDAR_ACTION:{...}]` | `actionPattern` | `CalendarActionController` |
| `[NOTE_ACTION:{...}]` | `noteActionPattern` | `NoteActionController` |
| `[CONTACTS_SEARCH:{...}]` | `contactsSearchPattern` | `ContactsActionController` |
| `[HABIT_ACTION:{...}]` | `habitActionPattern` | `HabitActionController` |
| `[REMINDER:{...}]` | `reminderActionPattern` | `ReminderActionController` |
| `[WEB_SEARCH:{...}]` | `webSearchPattern` | Extracted only — `ChatViewModel` triggers the search |

All regexes support one level of nested `{}` to accommodate recurrence fields and sub-objects. Matches are processed in **reverse order** so string replacement offsets remain valid.

## Protocol Decomposition

`SystemPromptBuilderProtocol` is a typealias composing six single-responsibility protocols:

```swift
typealias SystemPromptBuilderProtocol = PromptAssemblerProtocol
    & CalendarActionExecutorProtocol
    & NoteActionExecutorProtocol
    & ContactsActionExecutorProtocol
    & HabitActionExecutorProtocol
    & ReminderActionExecutorProtocol
    & WebSearchExtractorProtocol
```

This allows `ChatViewModel` to depend on the combined type while each protocol can be mocked independently in tests.

## `IdentityPromptSection` Detail

```swift
// Example output:
"You are LucidPal, an on-device AI assistant with direct read and write access
to the user's iOS calendar with access to the user's Notes, Reminders, and Mail.
Today is Wednesday, April 2, 2026 at 9:15 AM. Timezone: America/Toronto.
Region: CA. User's city: Montreal.
Be concise. Use markdown for emphasis (**bold**), bullet lists (- item),
and inline code (`code`). Keep responses short."
```

The section is adaptive — capability clauses (calendar, notes/reminders/mail) are omitted when permissions are not granted.

## Extension Points

To add a new tool capability:

1. Create a new `PromptSection` conformer (e.g. `FilesPromptSection`).
2. Return the tool's instruction block from `build()` — return `nil` if the feature is disabled.
3. Set `includedInSynthesis` to `false` if the tool must not be re-invoked during synthesis.
4. Inject it into the `sections` array in the `SystemPromptBuilder` convenience initialiser.
5. Add an action controller and a new executor protocol if the tool embeds `[ACTION:{...}]` blocks.

No changes to `SystemPromptBuilder`'s core `assemblePrompt` logic are needed.
