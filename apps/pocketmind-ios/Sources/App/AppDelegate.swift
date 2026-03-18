import UIKit

/// Minimal UIApplicationDelegate adopted via @UIApplicationDelegateAdaptor.
/// Required to receive the background URL session completion handler from the system
/// when the model download finishes while the app is suspended.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Stored by the OS when it wakes the app for a completed background URL session.
    /// ModelDownloader calls this in urlSessionDidFinishEvents(forBackgroundURLSession:)
    /// to tell the system it has finished processing all background events.
    var backgroundSessionCompletionHandler: (() -> Void)?

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        backgroundSessionCompletionHandler = completionHandler
    }
}
