# CI/CD Pipeline

LucidPal uses [Fastlane](https://fastlane.tools) for build automation and GitHub Actions for continuous delivery.

## Fastlane Lanes

All lanes run from `apps/lucidpal-ios/` via `bundle exec fastlane ios <lane>`.

| Lane | Command | Description |
|------|---------|-------------|
| `device` | `fastlane ios device` | Build debug IPA and install on connected iPhone via `xcrun devicectl` |
| `beta` | `fastlane ios beta` | Build release IPA, increment build number, and upload to TestFlight |
| `release` | `fastlane ios release` | Build release IPA and submit to App Store Connect (manual review trigger) |
| `provision` | `fastlane ios provision` | Register App IDs (`app.lucidpal`, `app.lucidpal.widget`) and App Group on Apple Developer Portal |
| `generate` | `fastlane ios generate` | Regenerate `.xcodeproj` from `project.yml` via XcodeGen |
| `prepare` | `fastlane ios prepare` | Check device connectivity via `xcrun xctrace` (USB or Wi-Fi, retries up to 10×) |
| `certs` | `fastlane ios certs` | Sync App Store certificates and profiles via `match` |
| `enable_groups` | `fastlane ios enable_groups` | Enable App Groups capability on both App IDs |

### Lane Details

#### `device`
1. Runs `prepare` → verifies device is reachable
2. Runs `generate` → regenerates `.xcodeproj`
3. Builds a `Debug` IPA with `development` export method
4. On CI: writes the ASC API key `.p8` to `/tmp/AuthKey_<id>.p8` for provisioning, then deletes it
5. Installs via `xcrun devicectl device install app --device <DEVICE_CORE_ID>`

#### `beta`
1. Conditionally runs `setup_ci` (keychain init) — skipped on M3 Max self-hosted runner
2. Runs `generate`
3. Loads ASC API key from env vars
4. Syncs `appstore` profiles via `match` (readonly)
5. Increments build number to `latest_testflight_build_number + 1`
6. Updates manual code signing settings for `LucidPal` and `LucidPalWidget` targets
7. Builds a `Release` IPA with `app-store` export method
8. Uploads to TestFlight (`skip_waiting_for_build_processing: true`)

#### `release`
1. Runs `generate`
2. Increments build number
3. Builds a `Release` IPA with automatic provisioning
4. Submits via `deliver` (does not auto-submit for review — manual trigger in App Store Connect)

#### `provision`
Run once after a bundle ID rename or new capability. Requires `FASTLANE_USER` and `FASTLANE_PASSWORD` (Apple ID credentials).

---

## GitHub Actions Workflows

### TestFlight (`testflight.yml`)

| Property | Value |
|----------|-------|
| Trigger | Push to `main` touching `apps/lucidpal-ios/**` (excludes `README.md`), or manual `workflow_dispatch` |
| Runner | `self-hosted, macos, ios, arm64` (M3 Max) |
| Timeout | 60 minutes |
| Concurrency | `testflight` group — cancels in-progress runs |

**Steps:**
1. Checkout repo
2. `bundle install` (Ruby gems)
3. `bundle exec fastlane ios beta` with secrets injected as env vars

### Deploy Docs (`docs.yml`)

| Property | Value |
|----------|-------|
| Trigger | Push to `main` touching `docs/**`, or manual `workflow_dispatch` |
| Runner | `ubuntu-latest` |
| Concurrency | `pages` group — does not cancel in-progress |

**Steps:**
1. Install Node 22, `npm install` in `docs/`
2. `npm run build`
3. Upload build artifact → deploy to GitHub Pages

---

## Required Secrets

Configure these in **GitHub → Settings → Secrets → Actions**:

| Secret | Used By | Description |
|--------|---------|-------------|
| `APP_STORE_CONNECT_API_KEY_ID` | `beta`, `device` (CI) | ASC API Key ID (e.g. `9W74KCHBGG`) |
| `APP_STORE_CONNECT_API_ISSUER_ID` | `beta`, `device` (CI) | ASC API Issuer ID (UUID) |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | `beta`, `device` (CI) | Base64-encoded `.p8` private key content |
| `MATCH_PASSWORD` | `beta` | Encryption password for `match` cert repo |
| `MATCH_GIT_BASIC_AUTHORIZATION` | `beta` | Base64 `user:token` for accessing the match git repo |

### Local Env Vars (optional overrides)

| Variable | Default | Description |
|----------|---------|-------------|
| `DEVICE_UDID` | `00008150-000C08842604401C` | Device UDID (`xcrun xctrace list devices`) |
| `DEVICE_CORE_ID` | `F8C4D569-E846-5445-B4EC-8B4B48714D01` | CoreDevice ID (`xcrun devicectl list devices`) |

---

## Local Developer Workflow

```bash
# One-time setup: register App IDs and App Group
fastlane ios provision

# Regenerate Xcode project after project.yml changes
fastlane ios generate

# Deploy to your iPhone (USB or Wi-Fi)
fastlane ios device
```

For device installation, the ASC API key env vars are optional locally — Xcode's existing session handles provisioning automatically.

---

## CI Workflow (GitHub Actions)

```
Push to main (apps/lucidpal-ios/**) →
  self-hosted M3 Max runner →
    bundle install →
      fastlane ios beta →
        generate → match certs → build Release → upload TestFlight
```

**Key differences from local:**

| Aspect | Local | CI |
|--------|-------|----|
| Keychain | Login keychain (existing) | Temporary CI keychain via `setup_ci` |
| ASC API key | Optional (Xcode session) | Required via secrets |
| `setup_ci` | Skipped (`RUNNER_NAME` starts with `cicd-m3max`) | Runs on headless runners |
| Device install | `xcrun devicectl` to physical device | Not run (beta lane only) |

---

## Self-Hosted Runner

The TestFlight workflow runs on a **self-hosted M3 Max arm64 macOS runner** (`RUNNER_NAME` prefix: `cicd-m3max`). This runner:

- Has a persistent login keychain — `setup_ci` is skipped
- Supports native Xcode 26 builds (arm64)
- Is identified in `testflight.yml` via `runs-on: [self-hosted, macos, ios, arm64]`

The `beta` lane detects whether it's running on this runner via:
```ruby
is_headless = ENV["CI"] && !ENV["RUNNER_NAME"]&.start_with?("cicd-m3max")
setup_ci if is_headless
```
