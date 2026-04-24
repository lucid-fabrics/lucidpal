---
sidebar_position: 2
---

# Quickstart

Build and run LucidPal on a physical iPhone in under 5 minutes.

## Prerequisites

| | |
|---|---|
| **Mac** | macOS 14+ (Sonoma), Xcode 16.0+ |
| **iPhone** | Any iPhone with 2 GB+ RAM, iOS 16+ |
| **iPhone connection** | USB or trusted on same Wi-Fi |
| **Tools** | `brew install xcodegen ios-deploy`, `gem install bundler` |

## Setup

### 1. Clone and install

```bash
git clone https://github.com/lucid-fabrics/lucidpal
cd lucidpal/apps/lucidpal-ios
bundle install
```

### 2. Open in Xcode

```bash
xcodegen generate
open LucidPal.xcodeproj
```

Or use the device lane directly (step 3).

### 3. Deploy to iPhone

```bash
bundle exec fastlane ios device
```

This lane:
1. Regenerates the Xcode project (`xcodegen generate`)
2. Builds for your connected device (auto-detected via CoreDevice)
3. Installs via `ios-deploy` (Wi-Fi if USB not connected)

On first launch, LucidPal prompts you to download an AI model and grant calendar permission. The app works fully offline after the model is downloaded.

---

## Development

### Run Tests

```bash
bundle exec fastlane ios tests
```

Or in Xcode: **Product → Test** (`⌘U`).

### Fastlane Lanes

| Lane | Command | Description |
|------|---------|-------------|
| `device` | `bundle exec fastlane ios device` | Build + install on connected iPhone |
| `tests` | `bundle exec fastlane ios tests` | Run full test suite |
| `generate` | `bundle exec fastlane ios generate` | Regenerate Xcode project only |
| `provision` | `bundle exec fastlane ios provision` | Register App IDs + App Group (one-time only) |

The commit-msg hook enforces a 72-character subject line limit. Commits over the limit are rejected automatically.

---

## What to Do Next

| Goal | Where to go |
|------|-------------|
| Chat with AI | Open LucidPal — tap mic or start typing |
| Calendar commands | "What's on tomorrow?" or "Add dentist Friday at 10am" |
| Download a model | First-launch carousel or Settings → Text Model |
| Voice input | Tap mic button on home screen or chat input bar |
| Siri shortcuts | Settings → Shortcuts — all intents are pre-configured |
| Habits / Notes | Tap the tab icons at the bottom of the screen |