---
sidebar_position: 2
---

# Quickstart

Build and run PocketMind on a physical iPhone in under 5 minutes.

## Prerequisites

**Mac requirements**
- macOS 14+ (Sonoma)
- Xcode 16.0+
- Ruby 3.2+ (`rbenv` or `rvm` recommended)

**iPhone requirements**
- iOS 17.0+ (on-device inference requires Neural Engine)
- Connected via USB or trusted on the same Wi-Fi network

**Tools**

```bash
brew install xcodegen ios-deploy
gem install bundler
```

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/lucid-fabrics/pocketmind.git
cd pocketmind/apps/pocketmind-ios
```

### 2. Install Ruby dependencies

```bash
bundle install
```

### 3. Deploy to iPhone

```bash
bundle exec fastlane ios device
```

This lane:
1. Runs `xcodegen generate` to regenerate `PocketMind.xcodeproj`
2. Builds with `xcodebuild` for the physical device
3. Installs via `ios-deploy`

### 4. Download a model

On first launch, PocketMind shows the **Model Download** screen. Tap **Download** to fetch the recommended Qwen3 model for your device (Wi-Fi recommended).

---

## Development Workflow

### Open in Xcode

```bash
cd apps/pocketmind-ios
xcodegen generate
open PocketMind.xcodeproj
```

### Run Tests

```bash
bundle exec fastlane ios tests
```

Or directly via Xcode: **Product → Test** (`⌘U`).

### Fastlane Lanes

| Lane | Command | Description |
|------|---------|-------------|
| `device` | `bundle exec fastlane ios device` | Build + install on connected iPhone |
| `tests` | `bundle exec fastlane ios tests` | Run full test suite |
| `generate` | `bundle exec fastlane ios generate` | Regenerate Xcode project only |

:::note
The commit-msg git hook enforces a 72-character subject line limit. Commits over the limit are rejected automatically.
:::
