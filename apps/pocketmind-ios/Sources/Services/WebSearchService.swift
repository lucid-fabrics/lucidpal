import Foundation
import OSLog

private let searchLogger = Logger(subsystem: "app.pocketmind", category: "WebSearch")

private enum HTTPStatus {
    /// HTTP 403 Forbidden — returned by SearXNG when JSON format is disabled.
    static let forbidden = 403
}

// MARK: - Provider

enum WebSearchProvider: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case brave
    case searxng

    var displayName: String {
        switch self {
        case .brave:   return "Brave Search"
        case .searxng: return "SearXNG (self-hosted)"
        }
    }
}

// MARK: - Domain model

struct WebSearchResult: Sendable {
    let title: String
    let url: String
    let snippet: String
}

// MARK: - Protocol

@MainActor
protocol WebSearchServiceProtocol: AnyObject {
    func search(query: String, maxResults: Int) async throws -> [WebSearchResult]
}

// MARK: - Implementation

@MainActor
final class WebSearchService: WebSearchServiceProtocol {

    private let settings: any WebSearchSettingsProtocol
    // nonisolated(unsafe): URLSession is thread-safe by design; injected once at init and never mutated.
    nonisolated(unsafe) private let session: URLSession

    init(settings: any WebSearchSettingsProtocol, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    func search(query: String, maxResults: Int = 5) async throws -> [WebSearchResult] {
        let results: [WebSearchResult]
        switch settings.webSearchProvider {
        case .brave:
            results = try await searchBrave(query: query, maxResults: maxResults)
        case .searxng:
            results = try await searchSearXNG(query: query, maxResults: maxResults)
        }
        let provider = settings.webSearchProvider.rawValue
        searchLogger.info("🔍 SEARCH [\(provider, privacy: .public)]: \"\(query, privacy: .public)\" → \(results.count) results")
        return results
    }

    // MARK: - Brave Search API

    private func searchBrave(query: String, maxResults: Int) async throws -> [WebSearchResult] {
        let apiKey = settings.braveApiKey
        guard !apiKey.isEmpty else { throw WebSearchError.missingCredentials }
        guard var components = URLComponents(string: "https://api.search.brave.com/res/v1/web/search") else {
            throw WebSearchError.invalidEndpoint
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: "\(maxResults)"),
        ]
        guard let url = components.url else { throw WebSearchError.invalidEndpoint }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, ChatConstants.httpSuccessRange.contains(http.statusCode) else {
            throw WebSearchError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let payload = try JSONDecoder().decode(BraveResponse.self, from: data)
        return (payload.web?.results ?? []).prefix(maxResults).map {
            WebSearchResult(title: $0.title, url: $0.url, snippet: $0.description ?? $0.title)
        }
    }

    // MARK: - SearXNG

    private func searchSearXNG(query: String, maxResults: Int) async throws -> [WebSearchResult] {
        let endpoint = settings.webSearchEndpoint
        guard !endpoint.isEmpty, let base = URL(string: endpoint) else {
            throw WebSearchError.invalidEndpoint
        }
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        let existingPath = components?.path ?? ""
        components?.path = existingPath.hasSuffix("/") ? existingPath + "search" : existingPath + "/search"
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components?.url else { throw WebSearchError.invalidEndpoint }
        let request = URLRequest(url: url, timeoutInterval: 10)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, ChatConstants.httpSuccessRange.contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw code == HTTPStatus.forbidden ? WebSearchError.searxngJsonDisabled : WebSearchError.httpError(code)
        }
        let payload = try JSONDecoder().decode(SearXNGResponse.self, from: data)
        return payload.results.prefix(maxResults).map {
            WebSearchResult(title: $0.title, url: $0.url, snippet: $0.content ?? $0.title)
        }
    }
}

// MARK: - Errors

enum WebSearchError: LocalizedError {
    case invalidEndpoint
    case missingCredentials
    case searxngJsonDisabled
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:      return "Web search endpoint not configured. Set it in Settings → Web Search."
        case .missingCredentials:   return "Brave API key not configured. Set it in Settings → Web Search."
        case .searxngJsonDisabled:  return "SearXNG JSON format is disabled. Add 'json' to search.formats in your settings.yml and restart SearXNG."
        case .httpError(let code):  return "Search request failed (HTTP \(code))."
        }
    }
}

// MARK: - Brave JSON response

private struct BraveResponse: Decodable {
    let web: BraveWeb?
}

private struct BraveWeb: Decodable {
    let results: [BraveResult]
}

private struct BraveResult: Decodable {
    let title: String
    let url: String
    let description: String?
}

// MARK: - SearXNG JSON response

private struct SearXNGResponse: Decodable {
    let results: [SearXNGResult]
}

private struct SearXNGResult: Decodable {
    let title: String
    let url: String
    let content: String?
}
