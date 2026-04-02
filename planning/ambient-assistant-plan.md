# Ambient Assistant — Implementation Plan

## Philosophy

LucidPal's promise: **just do the job and remind you.**

The microphone is the front door. Habits and notes are not apps the user manages — they are things the assistant tracks and surfaces. The user should rarely need to open the Habits or Notes tabs. The assistant knows their day, their streaks, their open notes — and volunteers that context at the right moment.

Current gap: habits and notes are bolted-on apps inside a personal assistant shell. The chat tab is reactive (user asks → assistant answers). The philosophy demands it be ambient (assistant knows, acts, and reminds proactively).

---

## What we are building

### 1. Daily Briefing (Chat landing transformation)

**Current state:** Empty microphone + time-of-day greeting + 3 suggested prompts.

**Target state:** When the user opens the app, the assistant leads with a contextual summary:

```
Good morning, Wassim.

Today: 3 events · 2h free window at 2pm
Habits: 0/5 logged · 6-day meditation streak 🔥
Notes: 2 pinned · "Cut sugar by May" added yesterday

[Microphone]
```

This card is generated once per session-open (not on every message), dismissed when the user starts talking, and regenerated on next cold open.

**What to build:**
- `DailyBriefingView` — SwiftUI card rendered above the microphone on first open of each session
- `DailyBriefingBuilder` — service that assembles the briefing from `HabitStore`, `NoteStore`, `CalendarService`, `AppSettings`
- Session tracking: show briefing only on first open per calendar day (store last-shown date in UserDefaults)
- Briefing collapses/dismisses when user taps mic or types

**Data inputs:**
- Habits: `habitStore.todayCompletionSummary()` + top active streak (`habitStore.streak(for:)`)
- Notes: pinned note count + most recently added note title
- Calendar: `calendarService` today's events + next free slot

**Files to create:**
- `Sources/Views/DailyBriefingView.swift`
- `Sources/Services/DailyBriefingBuilder.swift`

**Files to modify:**
- `Sources/Views/SessionListView.swift` — inject briefing above message list / mic
- `Sources/ViewModels/SessionListViewModel.swift` — expose briefing state

---

### 2. Onboarding voice-logging affordance

**Current state:** Onboarding teaches what data LucidPal can access. It does not teach that users can log habits or save notes by speaking.

**Target state:** A new onboarding page (or addition to the existing data sources page) with examples:

```
"I just meditated for 10 minutes"  → logged ✓ 6-day streak
"Remember: buy oat milk"           → saved to notes ✓  
"What did I say about my sleep?"   → surfaces relevant note
```

**Files to modify:**
- `Sources/Views/OnboardingCarouselView.swift` — add page or section showing voice-first usage examples

---

### 3. Habits tab — Review surface

**Current state:** Habits tab is the primary logging interface. Tap the ring to log. Templates shown when empty.

**Target state:**
- **Primary logging stays** (tap still works — it's a fast fallback)
- **Add weekly trend section** below the habit grid: 7-day completion bar per habit
- **Remove "Start with a template" from the active-habits view** (it's discovery UX, not daily use) — keep it only in empty state
- **Streak leaderboard** at top: top 3 streaks surface as hero cards
- Tab subtitle changes to "Review" language ("Here's your week")

**Files to modify:**
- `Sources/Views/HabitDashboardView.swift` — add `weeklyTrendsSection`, `streakHeroSection`; move `templateSuggestions` back to empty state only
- `Sources/Services/HabitStore.swift` — add `topStreaks(limit:)` helper

---

### 4. Notes tab — Memory Archive

**Current state:** Notes list with pinned section, category filter, search. AI creates notes via chat.

**Target state:**
- Surface AI summary prominently on each note card
- Add "From conversation" source badge (notes created via chat show a chat bubble icon)
- Add a "Memories" section: notes the AI has referenced in conversation (tracked via a `lastReferencedAt` timestamp)
- No structural change needed — the tab already works as a browse surface

**Files to modify:**
- `Sources/Views/NotesListView.swift` — source badge, AI summary preview, lastReferencedAt sort option
- `Sources/Models/NoteItem.swift` — add `lastReferencedAt: Date?` field (backward-compat optional)
- `Sources/Services/NoteActionController.swift` — set `lastReferencedAt` when note is surfaced in context

---

### 5. Widget Evolution

**Current state:** 3 widget sizes (small/medium/large), calendar-only. No AppGroup — widget reads EventKit directly. No habit or note data.

**Target state:** Widgets evolve to reflect the ambient assistant philosophy — they should show the user's day + habit pulse + a pinned note, not just calendar slots.

#### 5a. App Group setup (infrastructure prerequisite)

Set up App Group `group.app.lucidpal` in both the main app target and WidgetExtension target (requires Xcode Signing & Capabilities — manual step).

Create `SharedDataStore` — a lightweight JSON writer (main app) / reader (widget):

```
App Group container/
  lucidpal_widget_snapshot.json   ← written by main app after habit/note changes
```

**Files to create:**
- `Sources/Services/WidgetSnapshotWriter.swift` — writes snapshot after habit log or note save
- `WidgetExtension/WidgetSnapshotReader.swift` — reads snapshot at widget refresh time
- `Shared/WidgetSnapshot.swift` — shared Codable model (must be in a shared target or copied)

**Snapshot model:**
```swift
struct WidgetSnapshot: Codable {
    let writtenAt: Date
    let habitsToday: Int          // done count
    let habitsTotal: Int          // active count
    let topStreakName: String?    // "Meditation"
    let topStreakDays: Int        // 6
    let pinnedNote: String?       // first pinned note title
    let nextEventTitle: String?   // fallback if EventKit fails in widget
    let nextEventStart: Date?
}
```

**Trigger writes in:**
- `HabitStore.logEntry()` → write snapshot
- `HabitStore.save()` → write snapshot
- `NoteActionController` after note create/update

#### 5b. Small widget — Habit pulse

**Current:** Next event countdown OR "Free today / Tap to ask anything"

**Target:**
- If habits < 100% done: show habit progress ring (done/total) + top streak name
- If all habits done: show streak celebration + next event
- Empty state (no habits configured): current behavior (next event)

```
┌─────────────┐
│  🔥 3/5     │
│  Meditation │
│  6 days     │
│  [mic icon] │
└─────────────┘
```

#### 5c. Medium widget — Split: Calendar + Habit pulse

**Current:** Next event (left) + free slots (right)

**Target:**
- Left: next event (unchanged)
- Right: habit ring progress + top streak OR pinned note snippet (whichever is more relevant — prefer habit ring until all done)

#### 5d. Large widget — Full ambient summary

**Current:** Up to 4 events + overflow count + "Ask your AI" CTA

**Target:** Three sections:
1. **Today's events** (up to 3, same as now)
2. **Habit pulse** — horizontal progress bar, habit count, top streak
3. **Pinned note** — first pinned note title + snippet (if any)

**Files to modify:**
- `WidgetExtension/WidgetModels.swift` — add `WidgetSnapshot` fields to `LucidPalWidgetEntry`
- `WidgetExtension/LucidPalWidgetProvider.swift` — read snapshot via `WidgetSnapshotReader`
- `WidgetExtension/SmallWidgetView.swift` — habit pulse layout
- `WidgetExtension/MediumWidgetView.swift` — split habit/calendar
- `WidgetExtension/LargeWidgetView.swift` — three-section layout
- `WidgetExtension/CalendarDataProvider.swift` — merge snapshot data with EventKit data

---

### 6. Proactive session-open nudge (Phase 2)

After Phase 1 stabilizes, add: if the user opens the app after 6pm with unlogged habits, the assistant leads with a specific prompt rather than generic greeting:

> "Hey — you still have 3 habits unlogged today. Want to knock them out?"

Implementation: `DailyBriefingBuilder` checks time-of-day + unlogged habit count and adjusts tone/CTA accordingly. No push notification required — it's ambient, not intrusive.

---

## Execution Phases

| Phase | Scope | Prerequisite |
|---|---|---|
| **1** | Daily Briefing card (chat landing) | None |
| **2** | Onboarding voice-logging affordance | None |
| **3** | Habits tab: streak heroes + weekly trends | None |
| **4** | Notes tab: source badge + lastReferencedAt | None |
| **5a** | App Group setup (Xcode, manual) | Manual step |
| **5b–5d** | Widget evolution | Phase 5a |
| **6** | Proactive evening nudge | Phase 1 |

Phases 1–4 are independent and can run in parallel.
Phase 5 requires the manual App Group Xcode step before code can be written.

---

## Documentation updates required

Every shipped phase requires a doc update before the PR merges.

| Doc file | Update needed |
|---|---|
| `docs/guides/habit-tracker.md` | Add voice-logging as primary flow; add streak hero section; update tab description |
| `docs/guides/notes.md` | Add `lastReferencedAt` field; add source badge; add "From conversation" section |
| `docs/guides/widgets-notifications.md` | Full rewrite: new widget layouts for all 3 sizes; AppGroup data flow; snapshot model |
| `docs/architecture/habit-store.md` | Add `topStreaks(limit:)` helper; add widget snapshot trigger |
| `docs/architecture/notes-store.md` | Add `lastReferencedAt` field; add `WidgetSnapshotWriter` trigger |
| `docs/architecture/system-prompt.md` | Add daily briefing as session-open context; update HabitPromptSection |
| **New:** `docs/architecture/widget-data-flow.md` | Document AppGroup, WidgetSnapshot model, write triggers, reader pattern |
| **New:** `docs/guides/daily-briefing.md` | User-facing: what the briefing shows, when it appears, how to dismiss |

---

## Non-goals

- Push notifications (out of scope — ambient in-app nudge only)
- Server sync or cloud backup of habits/notes
- Lock screen widgets (complication level — future)
- Apple Watch app
- Reminders/Mail integration (marked orphaned in codebase — out of scope)

---

*Plan version: 1.0 — 2026-04-02*
