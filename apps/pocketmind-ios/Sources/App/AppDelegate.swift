import UIKit

/// Minimal UIApplicationDelegate adopted via @UIApplicationDelegateAdaptor.
/// Required to receive the background URL session completion handler from the system
/// when the model download finishes while the app is suspended.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Store on ModelDownloader so the service can call it without importing UIKit.
        ModelDownloader.backgroundSessionCompletion = completionHandler
    }
}
