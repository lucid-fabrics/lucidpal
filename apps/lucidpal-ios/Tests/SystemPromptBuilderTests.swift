@testable import LucidPal
import XCTest

@MainActor
final class PromptSectionTests: XCTestCase {

    private var sut: SystemPromptBuilder!

    override func setUp() async throws {
        try await super.setUp()
        sut = SystemPromptBuilder(
            sections: [],
            calendarActionController: MockCalendarActionController()
        )
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - extractWebSearchQuery

    func testReturnsNilForTextWithNoTag() {
        XCTAssertNil(sut.extractWebSearchQuery(from: "Just a regular message with no tags."))
    }

    func testReturnsNilForEmptyString() {
        XCTAssertNil(sut.extractWebSearchQuery(from: ""))
    }

    func testParsesValidTagWithQueryAndMaxResults() {
        let text = #"[WEB_SEARCH:{"query":"test","maxResults":3}]"#
        let result = sut.extractWebSearchQuery(from: text)
        XCTAssertEqual(result?.query, "test")
        XCTAssertEqual(result?.maxResults, 3)
    }

    func testDefaultMaxResultsWhenAbsent() {
        let text = #"[WEB_SEARCH:{"query":"hello"}]"#
        let result = sut.extractWebSearchQuery(from: text)
        XCTAssertEqual(result?.query, "hello")
        XCTAssertEqual(result?.maxResults, 5)
    }

    func testReturnsNilForMalformedJSON() {
        let text = "[WEB_SEARCH:{invalid}]"
        XCTAssertNil(sut.extractWebSearchQuery(from: text))
    }

    func testReturnsNilWhenTagIsIncomplete() {
        // Opening tag present but no closing bracket — regex won't match
        let text = "Here is [WEB_SEARCH: and then nothing"
        XCTAssertNil(sut.extractWebSearchQuery(from: text))
    }

    func testReturnsFirstMatchForMultipleTags() {
        let text = #"[WEB_SEARCH:{"query":"first","maxResults":2}] some text [WEB_SEARCH:{"query":"second","maxResults":7}]"#
        let result = sut.extractWebSearchQuery(from: text)
        XCTAssertEqual(result?.query, "first")
        XCTAssertEqual(result?.maxResults, 2)
    }

    func testParsesQueryWithSpaces() {
        let text = #"[WEB_SEARCH:{"query":"weather in Montreal","maxResults":5}]"#
        let result = sut.extractWebSearchQuery(from: text)
        XCTAssertEqual(result?.query, "weather in Montreal")
        XCTAssertEqual(result?.maxResults, 5)
    }

    // MARK: - CalendarPromptSection

    func testCalendarPromptSectionReturnsNilWhenNotAuthorized() async {
        let calendar = MockCalendarService()
        calendar.isAuthorized = false
        let settings = MockAppSettings()
        settings.calendarAccessEnabled = true
        let section = CalendarPromptSection(calendarService: calendar, settings: settings)
        let result = await section.build()
        XCTAssertNil(result, "CalendarPromptSection must return nil when calendar is not authorized")
    }

    func testCalendarPromptSectionReturnsNilWhenDisabledInSettings() async {
        let calendar = MockCalendarService()
        calendar.isAuthorized = true
        let settings = MockAppSettings()
        settings.calendarAccessEnabled = false
        let section = CalendarPromptSection(calendarService: calendar, settings: settings)
        let result = await section.build()
        XCTAssertNil(result, "CalendarPromptSection must return nil when calendarAccessEnabled is false")
    }

    // MARK: - WebSearchPromptSection

    func testWebSearchPromptSectionReturnsNilWhenDisabled() async {
        let settings = MockAppSettings()
        settings.webSearchEnabled = false
        settings.webSearchEndpoint = "http://localhost:8888"
        let section = WebSearchPromptSection(settings: settings)
        let result = await section.build()
        XCTAssertNil(result, "WebSearchPromptSection must return nil when webSearchEnabled is false")
    }

    func testWebSearchPromptSectionReturnsNilWhenEndpointEmpty() async {
        let settings = MockAppSettings()
        settings.webSearchEnabled = true
        settings.webSearchProvider = .searxng
        settings.webSearchEndpoint = ""
        let section = WebSearchPromptSection(settings: settings)
        let result = await section.build()
        XCTAssertNil(result, "WebSearchPromptSection must return nil when endpoint is empty")
    }

    func testWebSearchPromptSectionReturnsContentWhenEnabled() async throws {
        let settings = MockAppSettings()
        settings.webSearchEnabled = true
        settings.webSearchProvider = .searxng
        settings.webSearchEndpoint = "http://localhost:8888"
        let section = WebSearchPromptSection(settings: settings)
        let built = await section.build()
        let result = try XCTUnwrap(built, "WebSearchPromptSection must return content when enabled with valid endpoint")
        XCTAssertTrue(result.contains("WEB_SEARCH"))
    }
}
