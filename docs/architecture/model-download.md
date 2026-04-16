---
sidebar_position: 12
---

# Model Download Pipeline

How LucidPal downloads, verifies, and primes GGUF model files before inference.

## Component Overview

| Component | Role |
| --------- | ---- |
| `ModelDownloader` | Background `URLSession` download, resume-data recovery, SHA-256 verification, retry logic |
| `ModelDownloadViewModel` | Bridges `ModelDownloader` to SwiftUI — publishes state, orchestrates sequential text + vision downloads, auto-loads on completion |
| `ModelPageCacheWarmer` | Prefetches model bytes into the kernel page cache after a successful download to cut first-inference latency |
| `AppDelegate` | Stores the OS background-session completion handler so iOS knows when all background events are processed |

## URLSession Background Download

`ModelDownloader.download(model:)` creates a `URLSessionConfiguration.background` session and then calls `getTasksWithCompletionHandler` to adopt any already-running transfer before creating a new one. This prevents duplicate tasks — and the download-progress oscillation that occurred when the app was resumed mid-download:

```swift
session.getTasksWithCompletionHandler { [weak self] _, _, downloadTasks in
    if let existing = downloadTasks.first {
        // Adopt in-flight task; restore real progress from its counters
        let received = existing.countOfBytesReceived
        let expected = existing.countOfBytesExpectedToReceive
        let adopted = expected > 0 ? max(0.0, min(1.0, Double(received) / Double(expected))) : 0.0
        Task { @MainActor [weak self] in
            self?.downloadTask = existing
            self?.state = .downloading(progress: adopted)
        }
        return
    }
    // No existing task — start fresh or resume from saved resume data
    let task = capturedResumeData != nil
        ? session.downloadTask(withResumeData: capturedResumeData!)
        : session.downloadTask(with: model.downloadURL)
    task.resume()
}
```

Session configuration:

```swift
let config = URLSessionConfiguration.background(withIdentifier: "app.lucidpal.model-download")
config.allowsCellularAccess = false       // WiFi only
config.isDiscretionary = false            // User-initiated — do not defer
config.sessionSendsLaunchEvents = true    // Wake app when download completes
let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
```

- **Session identifier** `app.lucidpal.model-download` is fixed. iOS uses it to reconnect the app to an in-progress transfer across launches or suspensions.
- `allowsCellularAccess = false` enforces WiFi-only; a cellular disconnection fires `NSURLErrorCancelled` via the system, which is treated as a system cancellation (not a user cancel) and triggers resume-data storage.

## Progress Tracking

`URLSessionDownloadDelegate.urlSession(_:downloadTask:didWriteData:)` computes a `[0, 1]` fraction:

```swift
let progress = max(0.0, min(1.0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
Task { @MainActor in self?.state = .downloading(progress: progress) }
```

This publishes `.downloading(progress:)` on every chunk, which `ModelDownloadViewModel` forwards to SwiftUI via `assign(to: &$downloadState)`.

## Resume Data on Network Failure

`pendingResumeData` stores `NSURLSessionDownloadTaskResumeData` from a failed task:

- On **system cancellation** (WiFi dropped, no cellular): resume data is saved and the state transitions to `.failed` with a "WiFi required" message.
- On **network errors**: resume data is saved so the next user-initiated retry resumes mid-file rather than restarting from 0%.
- On **explicit user cancel** (`cancel()` is called): `pendingResumeData` is discarded — the full download restarts on the next tap.
- On **corrupt resume data** (`NSURLErrorCannotResumeDownload`, code `-3006`): `pendingResumeData` is cleared so the next retry starts fresh.

At the start of `download()`:

```swift
if let resumeData = pendingResumeData {
    task = session.downloadTask(withResumeData: resumeData)
    pendingResumeData = nil
} else {
    task = session.downloadTask(with: model.downloadURL)
}
```

## SHA-256 Integrity Verification

After the file lands in a temporary location, `verifyChecksum(of:)` streams the file through `CryptoKit.SHA256` in 64 KB chunks:

```swift
var hasher = SHA256()
while true {
    guard let chunk = try? handle.read(upToCount: 65_536), !chunk.isEmpty else { break }
    hasher.update(data: chunk)
}
return hasher.finalize()
```

The expected hex from `ModelInfo.sha256` is decoded to raw bytes and compared with `Digest.elementsEqual` (constant-time). String comparison is intentionally avoided to prevent timing side-channels.

If no `sha256` is set on a `ModelInfo`, verification is skipped (returns `true`).

## Retry Logic

On a checksum mismatch:

1. The corrupt temp file is deleted.
2. `checksumRetryCount` is incremented.
3. If `checksumRetryCount < 2` (max two auto-retries), `isRetryingChecksum = true`, state resets to `.downloading(progress: 0)`, and after a 1.5 s sleep `download(model:)` is called again.
4. Calls to `download()` during the sleep are blocked by `isRetryingChecksum`.
5. If the user cancels during the sleep, the `state == .idle` guard aborts the retry.
6. After two consecutive failures, `checksumRetryCount` resets to `0` and state transitions to `.failed` with a "Download corrupted" message.

## File Placement

Successful downloads are moved from the URLSession temporary location to `ModelInfo.localURL`, which resolves to the app's **Documents directory**:

```
<Documents>/<model-filename>.gguf
```

If a file already exists at the destination, `FileManager.replaceItemAt(_:withItemAt:)` is used — this is atomic on the same volume, so a failed replacement leaves the original intact. For new files, `moveItem(at:to:)` is used.

Companion `mmproj` (vision projector) files follow the same pattern and are cleaned up by `deleteModel(_:)` alongside the main GGUF.

## ModelPageCacheWarmer

After a successful download, `ModelPageCacheWarmer.hint(fileURL:)` issues an `fcntl(F_RDADVISE)` advisory to the kernel for the first 64 MB of the file (capped at 128 MB):

```swift
var ra = radvisory(ra_offset: 0, ra_count: Int32(clamping: clamped))
fcntl(fd, F_RDADVISE, &ra)
```

This tells the kernel to prefetch model pages into the page cache **before** `llama.cpp` memory-maps the file, eliminating demand-paging stalls during the first inference pass.

The warmer includes a sandbox containment check — it resolves symlinks on both the Documents directory and the target file, then verifies path components to prevent a symlink inside Documents from pointing outside the sandbox.

`ModelPageCacheWarmer` is a static `enum` with no stored state. It is safe to call from any thread and is a no-op if the file is missing or the `F_RDADVISE` hint fails.

## ModelDownloadViewModel

`ModelDownloadViewModel` is a `@MainActor ObservableObject` that bridges `ModelDownloaderProtocol` to SwiftUI.

### Published State

| Property | Type | Purpose |
| -------- | ---- | ------- |
| `downloadState` | `DownloadState` | Forwarded from `downloader.statePublisher` via `assign(to:)` |
| `isModelLoaded` | `Bool` | Forwarded from `llmService.isLoadedPublisher` |
| `isModelLoading` | `Bool` | Forwarded from `llmService.isLoadingPublisher` |
| `selectedModel` | `ModelInfo` | Currently selected model for download/load |
| `selectedTextModelID` | `String` | ID of the last successfully loaded text model (persisted) |
| `loadError` / `deleteError` | `String?` | Error messages surfaced to the UI |
| `deviceRAMGB` | `Int` | Passthrough from `settings.deviceRAMGB` |
| `hasProChip` | `Bool` | Passthrough from `settings.hasProChip` — used by catalog views to gate Pro-only models |

`isModelSupported(_ model: ModelInfo) -> Bool` returns whether the model's `minimumRAMGB` fits within `settings.deviceRAMGB`. `selectModel()` and `startDownload()` are no-ops for unsupported models.

### State Transitions

```
idle
 └─ startDownload() ──► downloading(progress: 0..1)
                              │
                    ┌─────────┴──────────┐
                    │                    │
               completed(url)        failed(message)
                    │
               loadModel() async
                    │
              isModelLoaded = true
                    │
               resetState() ──► idle
```

`assign(to: &$downloadState)` uses `weak self` internally (no retain cycle). The `statePublisher` sink that watches for `.completed` captures `selectedModel` at subscription time to avoid loading the wrong model if `selectedModel` changes mid-download.

### Sequential Vision Download

`startDownload(then:)` accepts an optional vision `ModelInfo`. After the text model finishes downloading and loads successfully, the ViewModel automatically starts the vision model download. Once the vision model loads, `selectedModel` is restored to the text model so the UI reflects the active text model.

### Launch Auto-Load

On init, if the saved text model is already on device and the LLM service is not loaded, the ViewModel loads text first, then vision (serialized to prevent concurrent `loadModel()` races).

## AppDelegate Background Session Handler

When iOS wakes the app to deliver events for the background download session, `AppDelegate` stores the OS completion handler:

```swift
func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
) {
    ModelDownloader.backgroundSessionCompletion = completionHandler
}
```

`ModelDownloader.urlSessionDidFinishEvents(forBackgroundURLSession:)` retrieves and calls this handler on `@MainActor` once all queued delegate events have been delivered, signalling to iOS that background processing is complete and a snapshot can be taken.

`backgroundSessionCompletion` is declared `nonisolated(unsafe) static` because it is written once from `AppDelegate` before any URLSession callbacks begin, and called once from the delegate — no concurrent access.
