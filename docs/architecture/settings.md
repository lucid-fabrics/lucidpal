---
sidebar_position: 15
---

# Settings System

How LucidPal stores, validates, and exposes user preferences.

## Overview

Settings follow the same **protocol-first** pattern as every other service layer. The concrete `AppSettings` class is instantiated once at the composition root (`LucidPalApp`) and injected into ViewModels via narrow sub-protocols.

```
AppSettingsProtocol
  ├── CalendarSettingsProtocol
  ├── InferenceSettingsProtocol
  ├── VoiceSettingsProtocol
  ├── WebSearchSettingsProtocol
  ├── LocationSettingsProtocol
  ├── VisionSettingsProtocol
  └── UISettingsProtocol          ← settingsMode (Simple / Advanced)
```

---

## SettingsMode

```swift
enum SettingsMode: String {
    case simple
    case advanced
}
```

`SettingsMode` is a `String`-backed enum stored in `UserDefaults`. The `UISettingsProtocol` sub-protocol exposes it so `SettingsView` can read it without importing the full `AppSettingsProtocol`.

| Mode | Visible sections |
|------|-----------------|
| `simple` | Data Sources, AI Model, Voice, General (Notifications, About, Debug Logs) |
| `advanced` | Everything in Simple + Vision model picker, full Inference controls (temperature, max tokens, timeout, KV cache), Siri Shortcuts section |

New installs default to `.simple`. The selected mode persists across launches.

---

## AppSettings

`AppSettings` is a `@MainActor` `ObservableObject`. Every preference is a `@Published` property backed by `UserDefaults.standard`. This means:

- SwiftUI views that observe `AppSettings` re-render automatically when any preference changes.
- Changes are written to `UserDefaults` immediately in each `didSet` observer — there is no explicit "save" step.

```swift
@MainActor
final class AppSettings: ObservableObject, AppSettingsProtocol {
    @Published var settingsMode: SettingsMode {
        didSet { UserDefaults.standard.set(settingsMode.rawValue,
                                           forKey: UserDefaultsKeys.settingsMode) }
    }
    @Published var calendarAccessEnabled: Bool { ... }
    @Published var thinkingEnabled: Bool { ... }
    // … all other preferences follow the same pattern
}
```

**Special case — Brave API key:** The Brave search API key is stored in the **iOS Keychain** (not `UserDefaults`) to prevent exposure in backups and system log access. All other preferences use `UserDefaults`.

**Notifications sync:** `LucidPalApp` observes `UIApplication.willEnterForegroundNotification` and calls `UNUserNotificationCenter.current().getNotificationSettings` to refresh `notificationsEnabled` each time the app returns to the foreground. This keeps the toggle in sync with the system permission state without requiring a restart.

---

## SettingsViewModel

`SettingsViewModel` is the `@MainActor` `ObservableObject` that drives `SettingsView`. It mirrors `AppSettings` values into its own `@Published` properties, applies validation, and calls service methods (e.g. location resolution, web-search connection test).

```
SettingsView ──observes──▶ SettingsViewModel
                                  │
                      ┌───────────┼───────────────┐
                      ▼           ▼               ▼
               AppSettings  CalendarService  LocationService
```

Key responsibilities:

| Responsibility | Detail |
|---------------|--------|
| **Calendar auth sync** | Reads `EKEventStore.authorizationStatus` and exposes it as `calendarAuthStatus` for conditional UI |
| **Location resolution** | Calls `LocationService.requestCity()` and writes the resolved city back to `AppSettings` |
| **Web search test** | `ConnectionTestResult` enum (`idle / testing / success(Int) / failure(String)`) drives a status label in the web search sub-screen |
| **Model lists** | Computes `availableTextModels` and `availableVisionModels` filtered to models compatible with the device's RAM |

---

## Protocol Segregation

Consumers that only need one concern import the narrowest protocol:

| Consumer | Protocol used |
|----------|--------------|
| `WebSearchService` | `WebSearchSettingsProtocol` |
| `SettingsView` | `UISettingsProtocol` (for mode picker) |
| `ChatViewModel` | `AppSettingsProtocol` (needs inference + calendar + voice) |
| `LLMService` | `InferenceSettingsProtocol` |

This follows the **Interface Segregation Principle** — callers only see the settings they need, and mocks only need to implement what is tested.

---

## Storage Keys

All `UserDefaults` keys are centralized in `UserDefaultsKeys.swift` as `static let` string constants. This prevents typos and makes renaming safe.

```swift
enum UserDefaultsKeys {
    static let settingsMode           = "settingsMode"
    static let calendarAccessEnabled  = "calendarAccessEnabled"
    static let selectedTextModelID    = "selectedTextModelID"
    // …
}
```

The Brave API key uses the same key name but reads/writes via `SecItemAdd` / `SecItemCopyMatching` (Keychain) instead of `UserDefaults`.
