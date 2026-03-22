import Foundation
@testable import PocketMind

@MainActor
final class MockWebSearchService: WebSearchServiceProtocol {
    var stubbedResults: [WebSearchResult] = []
    var stubbedError: Error?
    var searchCalled = false
    var lastQuery: String?
    var lastMaxResults: Int?

    func search(query: String, maxResults: Int) async throws -> [WebSearchResult] {
        searchCalled = true
        lastQuery = query
        lastMaxResults = maxResults
        if let error = stubbedError { throw error }
        return Array(stubbedResults.prefix(maxResults))
    }
}
