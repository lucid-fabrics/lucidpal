import Foundation

enum DownloadState: Equatable {
    case idle
    case downloading(progress: Double)
    case completed(url: URL)
    case failed(message: String)
}

@MainActor
final class ModelDownloader: NSObject, ObservableObject {
    @Published var state: DownloadState = .idle

    private var session: URLSession?
    private var downloadTask: URLSessionDownloadTask?

    // Safety: destinationURL is written on @MainActor before the download task starts,
    // and only read in URLSession delegate callbacks (which fire after the task resumes).
    // URLSession serialises delegate calls on its own queue so there is no concurrent
    // write/read. nonisolated(unsafe) is the correct annotation for this pattern.
    nonisolated(unsafe) private var destinationURL: URL?

    func download(model: ModelInfo) {
        // Idempotency guard — prevent double-download race condition
        guard downloadTask == nil else { return }

        destinationURL = model.localURL

        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = false  // WiFi-only; expose as user toggle in v2
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session

        let task = session.downloadTask(with: model.downloadURL)
        downloadTask = task
        state = .downloading(progress: 0)
        task.resume()
    }

    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        session?.invalidateAndCancel()
        session = nil
        state = .idle
    }

    func deleteModel(_ model: ModelInfo) throws {
        if FileManager.default.fileExists(atPath: model.localURL.path) {
            try FileManager.default.removeItem(at: model.localURL)
        }
    }
}

extension ModelDownloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let destination = destinationURL else { return }
        do {
            // Remove any pre-existing file (e.g. prior failed/partial download)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            Task { @MainActor [weak self] in
                self?.downloadTask = nil
                self?.state = .completed(url: destination)
            }
        } catch CocoaError.fileWriteOutOfSpace {
            // Clean up partial file if it was created before disk ran out
            try? FileManager.default.removeItem(at: destination)
            Task { @MainActor [weak self] in
                self?.downloadTask = nil
                self?.state = .failed(message: "Not enough storage space. Free up space and try again.")
            }
        } catch {
            try? FileManager.default.removeItem(at: destination)
            Task { @MainActor [weak self] in
                self?.downloadTask = nil
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

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error, (error as NSError).code != NSURLErrorCancelled else { return }
        Task { @MainActor [weak self] in
            self?.downloadTask = nil
            self?.state = .failed(message: error.localizedDescription)
        }
    }
}
