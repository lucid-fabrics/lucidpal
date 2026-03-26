import Foundation
@testable import LucidPal

@MainActor
final class MockContextService: ContextServiceProtocol {
    var isNotesEnabled = false
    var isRemindersEnabled = false
    var isMailEnabled = false

    var stubbedContext: String? = nil
    var shouldThrowOnFetch = false
    var fetchCallCount = 0
    var lastQuery: String? = nil

    var requestNotesAccessResult = false
    var requestRemindersAccessResult = false
    var requestMailAccessResult = false

    func fetchContext(query: String?) async -> String? {
        fetchCallCount += 1
        lastQuery = query
        return stubbedContext
    }

    func requestNotesAccess() async -> Bool {
        isNotesEnabled = requestNotesAccessResult
        return requestNotesAccessResult
    }

    func requestRemindersAccess() async -> Bool {
        isRemindersEnabled = requestRemindersAccessResult
        return requestRemindersAccessResult
    }

    func requestMailAccess() async -> Bool {
        isMailEnabled = requestMailAccessResult
        return requestMailAccessResult
    }
}
