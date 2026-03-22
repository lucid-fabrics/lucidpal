import Combine
import Foundation
import OSLog

private let logger = Logger(subsystem: "app.pocketmind", category: "ModelDownloader")

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

    // Set by AppDelegate when the OS wakes the app for a completed background session.
    // Called in urlSessionDidFinishEvents to signal the OS that processing is complete.
    // nonisolated(unsafe): written once from AppDelegate before concurrent URLSession callbacks begin.
    nonisolated(unsafe) static var backgroundSessionCompletion: (() -> Void)?

    func download(model: ModelInfo) {
        // Idempotency guard — prevent double-download race condition
        guard downloadTask == nil else { return }

        destinationURL = model.localURL

        // Background session: download continues even when the app is suspended.
        // The same identifier is used across launches so the system can reconnect.
        let config = URLSessionConfiguration.background(withIdentifier: "app.pocketmind.model-download")
        config.allowsCellularAccess = false
        config.isDiscretionary = false       // User-initiated — don't defer to low-power windows
        config.sessionSendsLaunchEvents = true
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session

        let task = session.downloadTask(with: model.downloadURL)
        downloadTask = task
        state = .downloading(progress: 0)
        task.resume()
    }

    func cancel() {
        userCancelled = true
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
        guard let destination = destinationURL else { return }

        // Validate HTTP status — HuggingFace can return 401/302→HTML on auth-gated models.
        // URLSessionDownloadTask fires this delegate even on non-200, saving the error HTML as
        // a file. Reject anything that isn't 200.
        if let httpResponse = downloadTask.response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            Task { @MainActor [weak self] in
                self?.downloadTask = nil
                self?.state = .failed(message: "Download failed: server returned HTTP \(httpResponse.statusCode). The model may require authentication.")
            }
            return
        }

        // Sanity-check file size: reject files under 10 MB (an HTML error page is a few KB).
        let minExpectedBytes: Int64 = 10 * 1024 * 1024
        let rawSize = try? FileManager.default.attributesOfItem(atPath: location.path)[.size] as? Int64 // safe: returns nil on failure
        if rawSize == nil { logger.warning("Could not read temp file attributes at \(location.path)") }
        let downloadedSize = rawSize ?? 0
        guard downloadedSize >= minExpectedBytes else {
            Task { @MainActor [weak self] in
                self?.downloadTask = nil
                self?.state = .failed(message: "Download appears corrupt (file too small: \(downloadedSize / 1024) KB). Check your connection and retry.")
            }
            return
        }

        do {
            // Remove any pre-existing file (e.g. prior failed/partial download)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            Task { @MainActor [weak self] in
                self?.downloadTask = nil
                self?.session?.finishTasksAndInvalidate()
                self?.session = nil
                self?.state = .completed(url: destination)
            }
        } catch CocoaError.fileWriteOutOfSpace {
            do {
                try FileManager.default.removeItem(at: destination)
            } catch {
                logger.error("Cleanup failed after disk-full error: \(error)")
            }
            Task { @MainActor [weak self] in
                self?.downloadTask = nil
                self?.session?.finishTasksAndInvalidate()
                self?.session = nil
                self?.state = .failed(message: "Not enough storage space. Free up space and try again.")
            }
        } catch {
            do {
                try FileManager.default.removeItem(at: destination)
            } catch {
                logger.error("Cleanup failed: \(error)")
            }
            Task { @MainActor [weak self] in
                self?.downloadTask = nil
                self?.session?.finishTasksAndInvalidate()
                self?.session = nil
                self?.state = .failed(message: error.localizedDescription)
            }
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
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
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

        // NSURLErrorCancelled fires for both user cancellation and cellular restriction
        // (allowsCellularAccess=false with no WiFi). Suppress only explicit user cancels.
        if nsError.code == NSURLErrorCancelled {
            let wasUserCancelled = userCancelled
            userCancelled = false
            guard !wasUserCancelled else { return }
        }

        let message = nsError.code == NSURLErrorCancelled
            ? "WiFi required to download models. Please connect to WiFi and try again."
            : error.localizedDescription

        Task { @MainActor [weak self] in
            self?.downloadTask = nil
            self?.state = .failed(message: message)
        }
    }
}
