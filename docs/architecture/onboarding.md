---
sidebar_position: 16
---

# Onboarding

First-launch experience: carousel pages, model selection, and permission requests.

## Flow

`ContentView` checks `AppSettings.hasCompletedOnboarding`. If `false`, it presents `OnboardingCarouselView` full-screen. Once the user taps **Get Started** on the last page, `hasCompletedOnboarding` is set to `true` and the session list is shown.

```
App launch
    │
    ▼
hasCompletedOnboarding?
    │ No
    ▼
OnboardingCarouselView (5 pages)
    ├── Page 1-3: Info pages (static content)
    ├── Page 4:   ModelSelectionPageView
    └── Page 5:   DataSourcesPageView  ← permission requests
    │
    ▼ "Get Started" tapped
hasCompletedOnboarding = true
    │
    ▼
SessionListView
```

---

## Page Structure

`OnboardingCarouselView` wraps a `TabView` with `.page` style. Page count = `infoPageCount` (3) + 2 (model selection + data sources) = **5 total**.

| Index | Page | Content |
|-------|------|---------|
| 0 | "Your Pocket AI" | Privacy + offline pitch |
| 1 | "Knows Your Schedule" | Calendar feature overview |
| 2 | "Type or Speak" | Voice input feature overview |
| 3 | Model Selection | `ModelSelectionPageView` |
| 4 | Data Sources | `DataSourcesPageView` — permission toggles |

A progress bar at the bottom reflects `currentPage / (totalPages - 1)`.

Navigation:
- **Next / Get Started** button advances or completes onboarding.
- **Skip** (visible on info pages) jumps to the last page (model selection).
- **Back** (visible on the last page only) returns to the previous page.

---

## ModelSelectionPageView

Presents all models compatible with the device's physical RAM, grouped into:

- **Primary models** — text or integrated (text + vision) models, sorted small → large by `minimumRAMGB`.
- **Vision add-ons** — dedicated vision-only models (reserved for future use; currently empty).

The recommended model (based on RAM) is highlighted with a "Recommended" badge. Selecting a model triggers `ModelDownloadViewModel.startDownload(_:)` immediately.

An integrated model handles both text and vision inference from a single `.gguf` file; selecting one hides the vision add-on picker.

---

## DataSourcesPageView

The final onboarding page. Presents a list of data source toggles and fires OS permission requests when the user enables a source that requires one.

| Toggle | Permission required | API used |
|--------|---------------------|----------|
| Notes | None (internal store) | — |
| Habits | None (internal store) | — |
| Contacts | `CNContactStore.requestAccess(for: .contacts)` | `ContactsService.requestAccess()` |
| Calendar | `EKEventStore.requestFullAccessToEvents()` | EventKit |
| Location | `CLLocationManager` (when-in-use) | `LocationService.requestCity()` |
| Web Search | None (network only, no OS permission) | — |

### Permission request flow

1. User flips a toggle to **On**.
2. The view's `onChange` handler fires on the main actor.
3. A `Task` calls the async permission helper (`requestCalendar()`, `requestContacts()`, or `requestLocation()`).
4. A `ProgressView` replaces the toggle while the request is in flight.
5. On completion, the result is written back to `AppSettings`:
   - Calendar: `settings.calendarAccessEnabled = granted`
   - Contacts: `settings.contactsAccessEnabled = granted`
   - Location: `settings.locationEnabled = true/false` and `settings.userCity = resolvedCity`
6. If the user denies the system prompt, the toggle reverts to `false` automatically.

All permission requests fire **lazily** — only when the user actively enables the source. No permissions are requested at app launch.

---

## Post-Onboarding State

After `handleGetStarted()` runs:

1. `AppSettings.hasCompletedOnboarding` → `true` (persisted in `UserDefaults`).
2. The selected vision add-on (if any) is written to `AppSettings.selectedVisionModelID`.
3. A `UINotificationFeedbackGenerator` fires a `.success` haptic.
4. `ContentView` transitions to `SessionListView`.

The download initiated on the model selection page continues in the background via `ModelDownloader`'s `URLSession` background transfer session — onboarding completion does not interrupt it.
