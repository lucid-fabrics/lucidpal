import Combine
import CryptoKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "app.lucidpal", category: "ModelDownloader")

enum DownloadState: Equatable, Sendable {
    case idle
    case downloading(progress: Double)
    case completed(url: URL)
    case failed(message: String)
}

/// Protocol abstraction for ModelDownloader — enables injection and mocking in unit tests.
@MainActor
protocol ModelDownloaderProtocol: AnyObject {
    var state: DownloadState { get }
    var statePublisher: AnyPublisher<DownloadState, Never> { get }
    func download(model: ModelInfo)
    func cancel()
    func resetState()
    func deleteModel(_ model: ModelInfo) throws
}

// @Published is kept (without ObservableObject) so downloader.$state publisher
// works for assign(to: &$downloadState) in ModelDownloadViewModel.
@MainActor
final class ModelDownloader: NSObject {
    @Published var state: DownloadState = .idle

    private var session: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    // Stored on failure so the next download() call can resume instead of restarting from 0%.
    private var pendingResumeData: Data?

    // Safety: destinationURL is written on @MainActor before the download task starts,
    // and only read in URLSession delegate callbacks (which fire after the task resumes).
    // URLSession serialises delegate calls on its own queue so there is no concurrent
    // write/read. nonisolated(unsafe) is the correct annotation for this pattern.
    nonisolated(unsafe) private var destinationURL: URL?

    // Tracks explicit user cancellation so we can distinguish it from a system-initiated
    // NSURLErrorCancelled (e.g. cellular blocked by allowsCellularAccess=false).
    // Safe: written on @MainActor in cancel(), read once in the delegate callback after
    // cancellation is issued — no concurrent read/write overlap.
    nonisolated(unsafe) private var userCancelled = false

    // Written on @MainActor in download() before the task starts; read synchronously in
    // the delegate callback after the file lands. Same safety pattern as destinationURL.
    nonisolated(unsafe) private var expectedSHA256: String?

    // Set by AppDelegate when the OS wakes the app for a completed background session.
    // Called in urlSessionDidFinishEvents to signal the OS that processing is complete.
    // nonisolated(unsafe): written once from AppDelegate before concurrent URLSession callbacks begin.
    nonisolated(unsafe) static var backgroundSessionCompletion: (() -> Void)?

    // Stored so auto-retry after checksum failure can restart the same model download.
    private var currentModel: ModelInfo?
    // Tracks how many consecutive checksum failures have triggered auto-retries.
    // Capped at 2 to prevent infinite retry loops on persistently corrupt CDN responses.
    private var checksumRetryCount = 0
    // Set during the 1.5 s sleep between checksum retries. Blocks download() so a
    // concurrent user-initiated retry cannot race with the scheduled auto-retry.
    private var isRetryingChecksum = false

    private let minimumExpectedModelBytes: Int64 = 10 * 1024 * 1024

    func download(model: ModelInfo) {
        // Idempotency guard — prevent double-download race condition.
        // Also check session == nil: background sessions are identified by a string;
        // iOS disallows two concurrent sessions with the same identifier. The old session
        // is invalidated asynchronously, so we must wait for it to fully drain (session=nil)
        // before creating a new one.
        // isRetryingChecksum blocks entry during the 1.5 s sleep between auto-retries so
        // a manual user tap cannot race with the scheduled restart.
        guard downloadTask == nil, session == nil, !isRetryingChecksum else { return }

        destinationURL = model.localURL
        expectedSHA256 = model.sha256
        currentModel = model

        // Background session: download continues even when the app is suspended.
        // The same identifier is used across launches so the system can reconnect.
        let config = URLSessionConfiguration.background(withIdentifier: "app.lucidpal.model-download")
        config.allowsCellularAccess = false
        config.isDiscretionary = false       // User-initiated — don't defer to low-power windows
        config.sessionSendsLaunchEvents = true
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session

        // Resume from saved data if available — avoids restarting a 600 MB+ download from 0%.
        let task: URLSessionDownloadTask
        if let resumeData = pendingResumeData {
            task = session.downloadTask(withResumeData: resumeData)
            pendingResumeData = nil
            logger.info("Resuming download from saved resume data (\(resumeData.count) bytes)")
        } else {
            task = session.downloadTask(with: model.downloadURL)
        }
        downloadTask = task
        state = .downloading(progress: 0)
        task.resume()
    }

    func cancel() {
        userCancelled = true
        pendingResumeData = nil  // discard — explicit user cancel, do not resume
        expectedSHA256 = nil
        currentModel = nil
        checksumRetryCount = 0
        isRetryingChecksum = false
        downloadTask?.cancel()
        downloadTask = nil
        session?.invalidateAndCancel()
        session = nil
        state = .idle
    }

    /// Resets the download state machine to idle. Called by the ViewModel after a
    /// successful model load to clear the stale "completed" state without bypassing
    /// the service's own state machine.
    func resetState() {
        state = .idle
    }

    func deleteModel(_ model: ModelInfo) throws {
        if FileManager.default.fileExists(atPath: model.localURL.path) {
            try FileManager.default.removeItem(at: model.localURL)
        }
        // Also delete the mmproj file if present
        if let mmprojURL = model.mmprojLocalURL,
           FileManager.default.fileExists(atPath: mmprojURL.path) {
            try FileManager.default.removeItem(at: mmprojURL)
        }
    }
}

extension ModelDownloader: ModelDownloaderProtocol {
    var statePublisher: AnyPublisher<DownloadState, Never> {
        $state.eraseToAnyPublisher()
    }
}

extension ModelDownloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let destination = destinationURL else {
            Task { @MainActor [weak self] in
                self?.downloadTask = nil
                self?.session?.finishTasksAndInvalidate()
                self?.session = nil
                self?.state = .failed(message: "Internal error: download destination was not set.")
            }
            return
        }

        if let failure = validateDownloadedFile(at: location, response: downloadTask.response) {
            Task { @MainActor [weak self] in
                self?.downloadTask = nil
                self?.session?.finishTasksAndInvalidate()
                self?.session = nil
                self?.state = .failed(message: failure)
            }
            return
        }

        // SHA256 integrity check — synchronous on the delegate queue (safe: URLSession
        // serialises callbacks). Returns true if validation passed or is not configured.
        if !verifyChecksum(of: location) { return }

        do {
            try moveDownloadedFile(from: location, to: destination)
            Task { @MainActor [weak self] in
                self?.downloadTask = nil
                self?.session?.finishTasksAndInvalidate()
                self?.session = nil
                self?.checksumRetryCount = 0  // reset after successful download
                self?.currentModel = nil
                self?.state = .completed(url: destination)
            }
        } catch {
            // Do NOT clean up destination: moveItem is atomic (nothing written on failure),
            // and replaceItemAt preserves the original file on failure.
            // Deleting destination here would remove the user's existing valid model.
            let message = (error as? CocoaError)?.code == .fileWriteOutOfSpace
                ? "Not enough storage space. Free up space and try again."
                : error.localizedDescription
            Task { @MainActor [weak self] in
                self?.downloadTask = nil
                self?.session?.finishTasksAndInvalidate()
                self?.session = nil
                self?.state = .failed(message: message)
            }
        }
    }

    // MARK: - Download Validation Helpers

    /// Returns a failure message if the downloaded file is invalid, `nil` if valid.
    private nonisolated func validateDownloadedFile(at location: URL, response: URLResponse?) -> String? {
        // Validate HTTP status — HuggingFace can return 401/302→HTML on auth-gated models.
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            return "Download failed: server returned HTTP \(httpResponse.statusCode). The model may require authentication."
        }

        // Sanity-check file size: reject files under 10 MB (an HTML error page is a few KB).
        let rawSize = try? FileManager.default.attributesOfItem(atPath: location.path)[.size] as? Int64
        if rawSize == nil { logger.warning("Could not read temp file attributes at \(location.path)") }
        let downloadedSize = rawSize ?? 0
        guard downloadedSize >= minimumExpectedModelBytes else {
            return "Download appears corrupt (file too small: \(downloadedSize / 1024) KB). Check your connection and retry."
        }

        return nil
    }

    /// Verifies the SHA256 of `location` against `expectedSHA256`.
    /// Returns true if the hash matches (or no expected hash is configured).
    /// On mismatch: deletes the temp file and schedules an auto-retry on MainActor.
    /// Uses CryptoKit Digest equality (constant-time) rather than hex-string comparison.
    private nonisolated func verifyChecksum(of location: URL) -> Bool {
        guard let expectedHex = expectedSHA256 else { return true }
        guard let actual = sha256Digest(of: location) else {
            logger.error("SHA256: could not read temp file at \(location.path)")
            Task { @MainActor [weak self] in
                self?.downloadTask = nil
                self?.session?.finishTasksAndInvalidate()
                self?.session = nil
                self?.state = .failed(message: "Could not verify download integrity.")
            }
            return false
        }
        // Decode expected hex to raw bytes and compare via Digest — constant-time equality.
        let expectedBytes = stride(from: 0, to: expectedHex.count, by: 2).compactMap { i -> UInt8? in
            let start = expectedHex.index(expectedHex.startIndex, offsetBy: i)
            let end = expectedHex.index(start, offsetBy: 2)
            return UInt8(expectedHex[start..<end], radix: 16)
        }
        guard expectedBytes.count == SHA256.Digest.byteCount,
              actual.elementsEqual(expectedBytes) else {
            let actualHex = actual.map { String(format: "%02x", $0) }.joined()
            logger.error("SHA256 mismatch: expected \(expectedHex), got \(actualHex)")
            try? FileManager.default.removeItem(at: location)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.downloadTask = nil
                self.session?.finishTasksAndInvalidate()
                self.session = nil
                self.pendingResumeData = nil  // corrupt session — must restart fresh
                if self.checksumRetryCount < 2, let model = self.currentModel {
                    self.checksumRetryCount += 1
                    self.isRetryingChecksum = true
                    self.state = .downloading(progress: 0)
                    try? await Task.sleep(for: .milliseconds(1_500))
                    self.isRetryingChecksum = false
                    guard self.state != .idle else { return }  // user cancelled during sleep
                    self.download(model: model)
                } else {
                    self.checksumRetryCount = 0
                    self.state = .failed(
                        message: "Download corrupted. Please tap retry to download again.")
                }
            }
            return false
        }
        return true
    }

    /// Streams the file at `url` through SHA256 in 64 KB chunks and returns the Digest.
    /// Returns nil only if the file cannot be opened.
    private nonisolated func sha256Digest(of url: URL) -> SHA256.Digest? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            // read(upToCount:) is the non-deprecated replacement for readData(ofLength:).
            guard let chunk = try? handle.read(upToCount: 65_536), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize()
    }

    /// Moves the temporary download to the final destination, replacing any existing file.
    /// Uses replaceItemAt when a prior file exists — this is atomic on the same volume,
    /// so a failed replacement leaves the original intact rather than deleting it first.
    private nonisolated func moveDownloadedFile(from source: URL, to destination: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(
                destination,
                withItemAt: source,
                backupItemName: nil,
                options: .usingNewMetadataOnly
            )
        } else {
            try FileManager.default.moveItem(at: source, to: destination)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = max(0.0, min(1.0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        Task { @MainActor [weak self] in
            self?.state = .downloading(progress: progress)
        }
    }

    /// Called after all background-session events have been delivered.
    /// Calls the stored completion handler so the OS knows we're done.
    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let handler = ModelDownloader.backgroundSessionCompletion
        ModelDownloader.backgroundSessionCompletion = nil
        Task { @MainActor in handler?() }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        let nsError = error as NSError

        // Capture resume data before branching — the system attaches it to the error
        // for both network failures and system-initiated cancellations (e.g. no WiFi).
        let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data

        // NSURLErrorCancelled fires for both user cancellation and cellular restriction
        // (allowsCellularAccess=false with no WiFi). Suppress only explicit user cancels.
        if nsError.code == NSURLErrorCancelled {
            let wasUserCancelled = userCancelled
            userCancelled = false
            if wasUserCancelled {
                // Explicit cancel — pendingResumeData already cleared in cancel(). Nothing to do.
                return
            }
            // System cancellation (e.g. WiFi dropped) — store resume data so the next
            // download() call picks up from where the transfer stopped.
            Task { @MainActor [weak self] in
                self?.pendingResumeData = resumeData
                self?.downloadTask = nil
                self?.session?.finishTasksAndInvalidate()
                self?.session = nil
                self?.state = .failed(message: "WiFi required to download models. Please connect to WiFi and try again.")
            }
            return
        }

        // Stale or corrupt resume data — the system cannot continue from the saved offset.
        // Clear it so the next retry starts fresh rather than looping on the same bad data.
        if nsError.code == NSURLErrorCannotResumeDownload {
            Task { @MainActor [weak self] in
                self?.pendingResumeData = nil
                self?.downloadTask = nil
                self?.session?.finishTasksAndInvalidate()
                self?.session = nil
                self?.state = .failed(message: "Download could not be resumed. Tap retry to start over.")
            }
            return
        }

        // Network or server failure — store resume data so retry resumes mid-file.
        Task { @MainActor [weak self] in
            self?.pendingResumeData = resumeData
            self?.downloadTask = nil
            self?.session?.finishTasksAndInvalidate()
            self?.session = nil
            self?.state = .failed(message: error.localizedDescription)
        }
    }
}
