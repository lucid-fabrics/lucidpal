import Foundation
import OSLog

private let searchLogger = Logger(subsystem: "app.pocketmind", category: "WebSearch")

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

// MARK: - SearXNG-compatible implementation

/// Calls any SearXNG-compatible JSON search endpoint.
/// Configure the base URL in Settings → Web Search (e.g. http://192.168.1.190:8888).
@MainActor
final class WebSearchService: WebSearchServiceProtocol {

    private let settings: any AppSettingsProtocol
    // nonisolated(unsafe): URLSession is thread-safe; only read from MainActor after init.
    nonisolated(unsafe) private let session: URLSession

    init(settings: any AppSettingsProtocol, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    func search(query: String, maxResults: Int = 5) async throws -> [WebSearchResult] {
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
        guard let url = components?.url else {
            throw WebSearchError.invalidEndpoint
        }
        let request = URLRequest(url: url, timeoutInterval: 10)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WebSearchError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let payload = try JSONDecoder().decode(SearXNGResponse.self, from: data)
        let results = payload.results.prefix(maxResults).map {
            WebSearchResult(title: $0.title, url: $0.url, snippet: $0.content ?? $0.title)
        }
        searchLogger.info("🔍 SEARCH: \"\(query, privacy: .public)\" → \(results.count) results")
        return Array(results)
    }
}

// MARK: - Errors

enum WebSearchError: LocalizedError {
    case invalidEndpoint
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return "Web search endpoint not configured. Set it in Settings → Web Search."
        case .httpError(let code): return "Search request failed (HTTP \(code))."
        }
    }
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
