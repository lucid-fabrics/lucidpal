import Foundation
import EventKit
import OSLog

private let contextLogger = Logger(subsystem: "app.pocketmind", category: "Context")

/// Aggregates cross-app context from Notes, Reminders, and Mail.
/// Respects user privacy opt-ins stored in UserDefaults.
/// @MainActor — EventKit fetchReminders callback only captures Sendable locals
/// (continuation, query, contextLogger); no self access inside the callback.
@MainActor
final class ContextService: ObservableObject {
    @Published private(set) var isNotesEnabled = false
    @Published private(set) var isRemindersEnabled = false
    @Published private(set) var isMailEnabled = false

    private let settings: any AppSettingsProtocol
    // EKEventStore is thread-safe per Apple docs; called from MainActor context.
    private let eventStore = EKEventStore()

    init(settings: any AppSettingsProtocol) {
        self.settings = settings
        self.isNotesEnabled = settings.notesAccessEnabled
        self.isRemindersEnabled = settings.remindersAccessEnabled
        self.isMailEnabled = settings.mailAccessEnabled
    }

    /// Fetches context from all enabled sources and returns formatted string.
    /// - Parameter query: Optional search query to filter results (e.g., "Montreal trip")
    func fetchContext(query: String?) async -> String? {
        var items: [ContextItem] = []

        if isNotesEnabled {
            items.append(contentsOf: await fetchNotesContext(query: query))
        }

        if isRemindersEnabled {
            items.append(contentsOf: await fetchRemindersContext(query: query))
        }

        if isMailEnabled {
            items.append(contentsOf: await fetchMailContext(query: query))
        }

        guard !items.isEmpty else { return nil }

        let formatted = items.map { $0.formatted() }.joined(separator: "\n")
        let header = "User's cross-app context (\(items.count) items from \(enabledSources())):"
        contextLogger.info("📱 CONTEXT_FETCHED: \(items.count) items from \(self.enabledSources(), privacy: .public)")
        return "\n\(header)\n\(formatted)"
    }

    // MARK: - Notes Context

    private func fetchNotesContext(query: String?) async -> [ContextItem] {
        // iOS 18+ has NotesKit, but it requires entitlements and App Store review.
        // Notes integration is blocked on Apple granting the com.apple.developer.notes.allow entitlement.
        // Implement CNNoteFetchRequest once the entitlement is approved.
        contextLogger.info("📝 NOTES: Not available (requires App Store entitlements)")
        return []
    }

    // MARK: - Reminders Context

    private func fetchRemindersContext(query: String?) async -> [ContextItem] {
        guard EKEventStore.authorizationStatus(for: .reminder) == .authorized else {
            contextLogger.warning("⚠️ REMINDERS: Not authorized")
            return []
        }

        let predicate = eventStore.predicateForReminders(in: nil)

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                guard let reminders = reminders else {
                    continuation.resume(returning: [])
                    return
                }

                let items = reminders.compactMap { reminder -> ContextItem? in
                    guard !reminder.isCompleted else { return nil }

                    // Filter by query if provided
                    if let query = query?.lowercased(),
                       !reminder.title.lowercased().contains(query),
                       !(reminder.notes?.lowercased().contains(query) ?? false) {
                        return nil
                    }

                    return ContextItem(
                        id: reminder.calendarItemIdentifier,
                        source: .reminders,
                        title: reminder.title,
                        content: reminder.notes,
                        date: reminder.dueDateComponents?.date,
                        metadata: [:]
                    )
                }

                contextLogger.info("✅ REMINDERS: Fetched \(items.count) items")
                continuation.resume(returning: items)
            }
        }
    }

    // MARK: - Mail Context

    private func fetchMailContext(query: String?) async -> [ContextItem] {
        // MailKit requires entitlements and is restricted to mail apps.
        // For consumer AI assistants, Mail integration is not available.
        // Alternative: Use MessageUI to compose, not read.
        contextLogger.info("📧 MAIL: Not available (MailKit restricted to mail apps)")
        return []
    }

    // MARK: - Permissions

    func requestNotesAccess() async -> Bool {
        // Notes access requires App Store entitlements
        contextLogger.info("📝 NOTES_ACCESS: Requires App Store entitlements")
        return false
    }

    func requestRemindersAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)

        switch status {
        case .notDetermined:
            do {
                let granted = try await eventStore.requestFullAccessToReminders()
                await MainActor.run {
                    isRemindersEnabled = granted
                    settings.remindersAccessEnabled = granted
                }
                contextLogger.info("✅ REMINDERS_ACCESS: \(granted ? "Granted" : "Denied")")
                return granted
            } catch {
                contextLogger.error("❌ REMINDERS_ACCESS: Error \(error.localizedDescription)")
                return false
            }
        case .authorized, .fullAccess:
            await MainActor.run {
                isRemindersEnabled = true
                settings.remindersAccessEnabled = true
            }
            return true
        case .denied, .restricted, .writeOnly:
            await MainActor.run {
                isRemindersEnabled = false
                settings.remindersAccessEnabled = false
            }
            return false
        @unknown default:
            return false
        }
    }

    func requestMailAccess() async -> Bool {
        // MailKit not available for consumer apps
        contextLogger.info("📧 MAIL_ACCESS: Not available (MailKit restricted)")
        return false
    }

    // MARK: - Helpers

    private func enabledSources() -> String {
        var sources: [String] = []
        if isNotesEnabled { sources.append("Notes") }
        if isRemindersEnabled { sources.append("Reminders") }
        if isMailEnabled { sources.append("Mail") }
        return sources.isEmpty ? "none" : sources.joined(separator: ", ")
    }
}

extension ContextService: ContextServiceProtocol {}
