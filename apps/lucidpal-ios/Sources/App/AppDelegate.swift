import BackgroundTasks
import EventKit
import os
import OSLog
import UIKit

private let bgLogger = Logger(subsystem: "app.lucidpal", category: "BackgroundTask")

/// Minimal UIApplicationDelegate adopted via @UIApplicationDelegateAdaptor.
final class AppDelegate: NSObject, UIApplicationDelegate {

    static let calendarRefreshTaskID = "app.lucidpal.calendar-refresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.calendarRefreshTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Self.handleCalendarRefresh(task: refreshTask)
        }
        return true
    }

    /// Receives the background URL session completion handler from the system
    /// when a model download finishes while the app is suspended.
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Store on ModelDownloader so the service can call it without importing UIKit.
        ModelDownloader.backgroundSessionCompletion = completionHandler
    }

    // MARK: - Calendar background refresh

    /// Schedules a BGAppRefreshTask to fire at least 15 minutes from now.
    /// Call this when the app enters the background.
    static func scheduleCalendarRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: calendarRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            bgLogger.error("BGTask submit failed: \(error, privacy: .private)")
        }
    }

    private static func handleCalendarRefresh(task: BGAppRefreshTask) {
        // Always re-schedule before doing work so the next refresh is queued.
        scheduleCalendarRefresh()

        // Atomic flag prevents double setTaskCompleted when the task completes
        // just as the system fires the expiration timer.
        let didComplete = OSAllocatedUnfairLock(initialState: false)
        var refreshTask: Task<Void, Never>?

        // Assign the task BEFORE registering the expirationHandler so that if the
        // system fires the handler immediately, refreshTask?.cancel() is never a no-op.
        refreshTask = Task {
            // Skip if access not already granted — background tasks cannot show
            // permission prompts, and the status won't change while suspended.
            guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
                let alreadyDone = didComplete.withLock { state -> Bool in
                    let was = state; state = true; return was
                }
                if !alreadyDone { task.setTaskCompleted(success: false) }
                return
            }
            guard !Task.isCancelled else {
                let alreadyDone = didComplete.withLock { state -> Bool in let was = state; state = true; return was }
                if !alreadyDone { task.setTaskCompleted(success: false) }
                return
            }
            // EKEventStore is created inside the Task to ensure it's allocated
            // on the thread that uses it.
            let store = EKEventStore()
            let now = Date()
            // Fallback uses addingTimeInterval in case Calendar arithmetic fails (e.g. extreme DST edge case).
            // predicateForEvents requires end > start; the ?? now fallback would violate this.
            let end = Calendar.current.date(byAdding: .day, value: 7, to: now)
                ?? now.addingTimeInterval(7 * 24 * 3_600)
            let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
            _ = store.events(matching: predicate) // warm EKEventStore in-process cache
            guard !Task.isCancelled else {
                let alreadyDone = didComplete.withLock { state -> Bool in let was = state; state = true; return was }
                if !alreadyDone { task.setTaskCompleted(success: false) }
                return
            }
            let alreadyDone = didComplete.withLock { state -> Bool in
                let was = state; state = true; return was
            }
            if !alreadyDone { task.setTaskCompleted(success: true) }
        }

        // Register the expiration handler AFTER assigning refreshTask so the
        // handler always sees a non-nil task to cancel. Strong capture of task
        // is intentional — BGAppRefreshTask is system-managed and won't be
        // released before setTaskCompleted is called.
        task.expirationHandler = {
            let alreadyDone = didComplete.withLock { state -> Bool in
                let was = state; state = true; return was
            }
            guard !alreadyDone else { return }
            refreshTask?.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
