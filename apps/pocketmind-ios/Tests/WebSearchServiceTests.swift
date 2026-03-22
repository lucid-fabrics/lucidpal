import XCTest
@testable import PocketMind

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol {
    // nonisolated(unsafe): test-only stub; URLProtocol invokes startLoading on a background thread
    // but tests set this only from the main actor via setUp/tearDown, so there is no data race in practice.
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - WebSearchServiceTests

@MainActor
final class WebSearchServiceTests: XCTestCase {

    private var service: WebSearchService!
    private var settings: MockAppSettings!
    private var session: URLSession!

    override func setUp() async throws {
        try await super.setUp()
        settings = MockAppSettings()
        settings.webSearchEndpoint = "http://localhost:8888"
        settings.webSearchEnabled = true

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        service = WebSearchService(settings: settings, session: session)
    }

    override func tearDown() async throws {
        MockURLProtocol.requestHandler = nil
        try await super.tearDown()
    }

    // MARK: - Success cases

    func testSearchReturnsResults() async throws {
        let json = """
        {"results": [
            {"title": "Result 1", "url": "https://example.com/1", "content": "Snippet 1"},
            {"title": "Result 2", "url": "https://example.com/2", "content": "Snippet 2"}
        ]}
        """
        stubResponse(statusCode: 200, body: json)

        let results = try await service.search(query: "test query", maxResults: 5)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].title, "Result 1")
        XCTAssertEqual(results[0].url, "https://example.com/1")
        XCTAssertEqual(results[0].snippet, "Snippet 1")
    }

    func testSearchRespectsMaxResults() async throws {
        let json = """
        {"results": [
            {"title": "A", "url": "https://a.com", "content": "a"},
            {"title": "B", "url": "https://b.com", "content": "b"},
            {"title": "C", "url": "https://c.com", "content": "c"}
        ]}
        """
        stubResponse(statusCode: 200, body: json)

        let results = try await service.search(query: "query", maxResults: 2)

        XCTAssertEqual(results.count, 2)
    }

    func testSearchFallsBackToTitleWhenContentMissing() async throws {
        let json = """
        {"results": [{"title": "Title Only", "url": "https://t.com"}]}
        """
        stubResponse(statusCode: 200, body: json)

        let results = try await service.search(query: "q", maxResults: 5)

        XCTAssertEqual(results[0].snippet, "Title Only")
    }

    func testSearchAppendsSearchPathToEndpoint() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let json = #"{"results":[]}"#
            return (self.makeResponse(statusCode: 200, url: req.url!), Data(json.utf8))
        }

        _ = try await service.search(query: "hello world", maxResults: 3)

        XCTAssertEqual(capturedURL?.path, "/search")
        XCTAssertTrue(capturedURL?.query?.contains("q=hello%20world") == true
                      || capturedURL?.query?.contains("q=hello+world") == true)
        XCTAssertTrue(capturedURL?.query?.contains("format=json") == true)
    }

    // MARK: - Error cases

    func testThrowsInvalidEndpointWhenEmpty() async throws {
        settings.webSearchEndpoint = ""

        do {
            _ = try await service.search(query: "test", maxResults: 5)
            XCTFail("Expected WebSearchError.invalidEndpoint")
        } catch WebSearchError.invalidEndpoint {
            // pass
        }
    }

    func testThrowsInvalidEndpointWhenMalformedURL() async throws {
        // A non-empty string that cannot produce a valid URL (e.g. contains only spaces).
        // This exercises the nil-URL guard branch independently of the empty-string guard.
        settings.webSearchEndpoint = "   "

        do {
            _ = try await service.search(query: "test", maxResults: 5)
            XCTFail("Expected WebSearchError.invalidEndpoint")
        } catch WebSearchError.invalidEndpoint {
            // pass
        }
    }

    func testThrowsHTTPErrorOn4xx() async throws {
        stubResponse(statusCode: 404, body: "Not Found")

        do {
            _ = try await service.search(query: "test", maxResults: 5)
            XCTFail("Expected WebSearchError.httpError")
        } catch WebSearchError.httpError(let code) {
            XCTAssertEqual(code, 404)
        }
    }

    func testThrowsHTTPErrorOn5xx() async throws {
        stubResponse(statusCode: 500, body: "Server Error")

        do {
            _ = try await service.search(query: "test", maxResults: 5)
            XCTFail("Expected WebSearchError.httpError")
        } catch WebSearchError.httpError(let code) {
            XCTAssertEqual(code, 500)
        }
    }

    func testThrowsOnNetworkFailure() async throws {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }

        do {
            _ = try await service.search(query: "test", maxResults: 5)
            XCTFail("Expected URLError")
        } catch is URLError {
            // pass
        }
    }

    func testThrowsOnMalformedJSON() async throws {
        stubResponse(statusCode: 200, body: "{ bad json }")

        do {
            _ = try await service.search(query: "test", maxResults: 5)
            XCTFail("Expected decoding error")
        } catch is DecodingError {
            // pass
        }
    }

    // MARK: - Helpers

    private func stubResponse(statusCode: Int, body: String) {
        MockURLProtocol.requestHandler = { [weak self] req in
            guard let self else { throw URLError(.cancelled) }
            return (makeResponse(statusCode: statusCode, url: req.url!), Data(body.utf8))
        }
    }

    private func makeResponse(statusCode: Int, url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
}
