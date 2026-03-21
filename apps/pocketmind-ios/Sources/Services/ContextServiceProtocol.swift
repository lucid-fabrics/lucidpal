import Foundation

/// Protocol abstraction for ContextService — enables mocking in unit tests
/// and decouples ViewModels from the concrete cross-app context implementation.
/// Not @MainActor — EventKit operations run on background queue.
protocol ContextServiceProtocol: AnyObject {
    var isNotesEnabled: Bool { get }
    var isRemindersEnabled: Bool { get }
    var isMailEnabled: Bool { get }

    /// Aggregates context from all enabled sources (Notes, Reminders, Mail).
    /// Returns formatted context string for LLM system prompt injection.
    func fetchContext(query: String?) async -> String?

    /// Request access permissions for each data source.
    func requestNotesAccess() async -> Bool
    func requestRemindersAccess() async -> Bool
    func requestMailAccess() async -> Bool
}
