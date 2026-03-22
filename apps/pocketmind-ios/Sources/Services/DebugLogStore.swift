import Foundation

// MARK: - DebugLogStore

/// In-memory ring buffer of structured log entries, readable from DebugLogView.
/// Call `DebugLogStore.shared.log(...)` at key instrumentation points.
@MainActor
final class DebugLogStore: ObservableObject {

    static let shared = DebugLogStore()
    private init() {}

    // MARK: - Entry

    struct Entry: Identifiable {
        let id = UUID()
        let date = Date()
        let category: String
        let level: Level
        let message: String

        enum Level: String, CaseIterable {
            case info    = "INFO"
            case warning = "WARN"
            case error   = "ERROR"

            var emoji: String {
                switch self {
                case .info:    return "ℹ️"
                case .warning: return "⚠️"
                case .error:   return "❌"
                }
            }
        }
    }

    // MARK: - Storage

    @Published private(set) var entries: [Entry] = []
    private let maxEntries = 500

    // MARK: - API

    func log(_ message: String, category: String, level: Entry.Level = .info) {
        entries.append(Entry(category: category, level: level, message: message))
        if entries.count > maxEntries { entries.removeFirst() }
    }

    func clear() { entries.removeAll() }
}
