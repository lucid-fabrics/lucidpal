# Changelog

All notable changes to PocketMind iOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **AirPods-First Voice Mode**: Hands-free automatic voice activation when AirPods are connected
  - `AudioRouteMonitor`: Detects AirPods and HomePod connections via AVAudioSession route monitoring
  - `AirPodsVoiceCoordinator`: Manages auto-voice activation based on AirPods connection state
  - Auto-listening indicator: Visual banner in ChatView when AirPods auto-voice is active
  - Audio interruption handling: Gracefully pauses/resumes recording during phone calls or media playback
  - Settings toggle: "AirPods auto-voice" option in Inference section
  - Seamless handoff: Auto-start when AirPods connect, fall back to manual tap when disconnected
  - Unit tests: `AudioRouteMonitorTests` and `AirPodsVoiceCoordinatorTests`

- **Shortcuts App Integration**: Expose PocketMind actions to iOS Shortcuts for automation
  - `Create Event` - Create calendar events with title, time, duration, location, notes (runs in background)
  - `Check Next Meeting` - Get details of upcoming calendar event (returns text response)
  - `Find Free Time` - Search for available time slots by date and duration (returns formatted slot)
  - `Ask PocketMind (Background)` - Quick query that opens app with pre-filled question
  - Siri voice activation phrases for each shortcut action
  - Shortcuts documentation section in Settings with visual guide and action descriptions
  - 4 new `AppIntent` types: `CreateEventShortcutIntent`, `CheckNextMeetingIntent`, `FindFreeTimeShortcutIntent`, `AskPocketMindShortcutIntent`
  - Direct EventKit integration for background calendar operations
  - Working hours logic for free time detection (8am-8pm, Mon-Fri)
  - Unit tests for parameter validation (`ShortcutIntentTests`)

- **Cross-App Context Engine**: AI can now access context from Apple Notes, Reminders, and Mail to answer questions like "What did I write about the Montreal trip?" or "Any reminders about the Alchemi presentation?"
  - `ContextService`: Aggregates data from Notes, Reminders, and Mail with user opt-in controls
  - `ContextServiceProtocol`: Protocol abstraction for testing and dependency injection
  - `ContextItem` model: Unified representation of context items across apps
  - Privacy controls: User must explicitly enable each data source (Notes, Reminders, Mail)
  - System prompt injection: Context automatically injected into LLM conversations when enabled
  - Reminders integration: Fetches incomplete reminders with optional query filtering
  - Info.plist permissions: Added NSRemindersUsageDescription and NSRemindersFullAccessUsageDescription
  - Unit tests: `ContextServiceTests` and `MockContextService` for testability

### Changed
- `SpeechService`: Added audio interruption handling with `isInterrupted` published property
- `ChatViewModel`: Added `isAutoListening` property and `AirPodsVoiceCoordinator` dependency
- `AppSettings`: Added `airpodsAutoVoiceEnabled` toggle (defaults to false)
- `AppSettingsProtocol`: Extended with `airpodsAutoVoiceEnabled` property
- `UserDefaultsKeys`: Added `airpodsAutoVoiceEnabled` key
- `SettingsView`: Added "AirPods auto-voice" toggle in Inference section
- `ChatView`: Added auto-listening banner UI when AirPods are active
- `PocketMindApp`: Initialized `AudioRouteMonitor` and `AirPodsVoiceCoordinator` services
- `SessionListViewModel`: Added `AirPodsVoiceCoordinator` dependency for ChatViewModel factory
- `PocketMindShortcuts`: Added 4 new shortcut entries with Siri phrases
- `SettingsView`: Added Shortcuts section with action documentation and link to Shortcuts app
- `ChatViewModel`: Now accepts `ContextServiceProtocol` dependency injection
- `AppSettings`: Added `notesAccessEnabled`, `remindersAccessEnabled`, `mailAccessEnabled` toggles
- `AppSettingsProtocol`: Extended with new context access properties
- `UserDefaultsKeys`: Added keys for Notes, Reminders, and Mail access toggles
- System prompt: Updated to include cross-app context when enabled

### Notes
- **Shortcuts**: All intents require calendar permissions; background execution enabled for Create Event, Check Next Meeting, and Find Free Time
- **Notes integration**: Requires App Store entitlements (NotesKit/CNNoteFetchRequest) - not yet implemented
- **Mail integration**: MailKit is restricted to mail apps only - not available for consumer AI assistants
- **Reminders integration**: Fully functional with EventKit (EKReminder)

---

## Previous Releases

See git commit history for earlier changes.
