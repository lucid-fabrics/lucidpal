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

    // nonisolated(unsafe) lets delegate callbacks write without actor hopping
    nonisolated(unsafe) private var destinationURL: URL?

    func download(model: ModelInfo) {
        destinationURL = model.localURL

        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = false  // WiFi-only by default
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
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            Task { @MainActor [weak self] in
                self?.state = .completed(url: destination)
            }
        } catch {
            Task { @MainActor [weak self] in
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
            self?.state = .failed(message: error.localizedDescription)
        }
    }
}
