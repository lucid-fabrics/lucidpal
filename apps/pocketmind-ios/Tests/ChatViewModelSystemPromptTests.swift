import XCTest
@testable import PocketMind

@MainActor
final class SystemPromptBuilderTests: XCTestCase {

    var calendar: MockCalendarService!
    var builder: SystemPromptBuilder!

    override func setUp() async throws {
        calendar = MockCalendarService()
        builder = SystemPromptBuilder(
            calendarService: calendar,
            contextService: MockContextService(),
            settings: MockAppSettings(),
            calendarActionController: MockCalendarActionController()
        )
    }

    // MARK: - actionPattern regex

    func testActionPatternMatchesSimpleCreateBlock() {
        let text = #"[CALENDAR_ACTION:{"action":"create","title":"Meeting"}]"#
        let regex = try? NSRegularExpression(pattern: SystemPromptBuilder.actionPattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex?.matches(in: text, range: range) ?? []
        XCTAssertEqual(matches.count, 1)
    }

    func testActionPatternMatchesMultipleBlocks() {
        let text = #"[CALENDAR_ACTION:{"action":"delete","search":"X"}] ok [CALENDAR_ACTION:{"action":"create","title":"Y"}]"#
        let regex = try? NSRegularExpression(pattern: SystemPromptBuilder.actionPattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex?.matches(in: text, range: range) ?? []
        XCTAssertEqual(matches.count, 2)
    }

    func testActionPatternDoesNotMatchMalformedBlock() {
        let text = "CALENDAR_ACTION no brackets here"
        let regex = try? NSRegularExpression(pattern: SystemPromptBuilder.actionPattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex?.matches(in: text, range: range) ?? []
        XCTAssertEqual(matches.count, 0)
    }

    // MARK: - buildSystemPrompt (identity section always present)

    func testBuildSystemPromptIsNonEmpty() async {
        let prompt = await builder.buildSystemPrompt()
        XCTAssertFalse(prompt.isEmpty)
    }

    func testBuildSystemPromptContainsTodaysDate() async {
        let prompt = await builder.buildSystemPrompt()
        let year = String(Calendar.current.component(.year, from: Date()))
        XCTAssertTrue(prompt.contains(year))
    }

    // MARK: - buildSystemPrompt (calendar section)

    func testBuildSystemPromptWithCalendarEnabledContainsCreateAction() async {
        let prompt = await promptWithCalendar()
        XCTAssertTrue(prompt.contains("create"))
    }

    func testBuildSystemPromptWithCalendarEnabledContainsDeleteAction() async {
        let prompt = await promptWithCalendar()
        XCTAssertTrue(prompt.contains("delete"))
    }

    func testBuildSystemPromptWithCalendarEnabledContainsQueryAction() async {
        let prompt = await promptWithCalendar()
        XCTAssertTrue(prompt.contains("query"))
    }

    func testBuildSystemPromptWithCalendarEnabledContainsISO8601Format() async {
        let prompt = await promptWithCalendar()
        XCTAssertTrue(prompt.contains("YYYY-MM-DDTHH:MM:SS"))
    }

    func testBuildSystemPromptWithCalendarEnabledContainsMandatoryRule() async {
        let prompt = await promptWithCalendar()
        XCTAssertTrue(prompt.contains("NEVER skip the block"))
    }

    func testBuildSystemPromptWithCalendarDisabledOmitsToolInstructions() async {
        let prompt = await builder.buildSystemPrompt()  // calendarAccessEnabled = false by default
        XCTAssertFalse(prompt.contains("CALENDAR TOOL"))
    }

    // MARK: - buildSynthesisPrompt

    func testBuildSynthesisPromptOmitsWebSearchSection() async {
        let settings = MockAppSettings()
        settings.webSearchEnabled = true
        settings.webSearchProvider = .searxng
        settings.webSearchEndpoint = "http://localhost:8888"
        let b = SystemPromptBuilder(
            calendarService: calendar,
            contextService: MockContextService(),
            settings: settings,
            calendarActionController: MockCalendarActionController()
        )
        // Full prompt includes WEB SEARCH TOOL; synthesis prompt must not.
        let fullPrompt = await b.buildSystemPrompt()
        let synthesisPrompt = await b.buildSynthesisPrompt()
        XCTAssertTrue(fullPrompt.contains("WEB SEARCH TOOL"))
        XCTAssertFalse(synthesisPrompt.contains("WEB SEARCH TOOL"))
    }

    // MARK: - executeCalendarActions

    func testExecuteCalendarActionsPassesThroughPlainText() async {
        let plain = "Hello, here are your events for today."
        let (content, previews, slots) = await builder.executeCalendarActions(in: plain)
        XCTAssertEqual(content, plain)
        XCTAssertTrue(previews.isEmpty)
        XCTAssertTrue(slots.isEmpty)
    }

    // MARK: - extractWebSearchQuery

    func testExtractWebSearchQueryReturnsNilForPlainText() {
        XCTAssertNil(builder.extractWebSearchQuery(from: "Hello world"))
    }

    func testExtractWebSearchQueryParsesQueryAndMaxResults() {
        let text = #"[WEB_SEARCH:{"query":"swift actors","maxResults":3}]"#
        let result = builder.extractWebSearchQuery(from: text)
        XCTAssertEqual(result?.query, "swift actors")
        XCTAssertEqual(result?.maxResults, 3)
    }

    func testExtractWebSearchQueryDefaultsMaxResultsToFive() {
        let text = #"[WEB_SEARCH:{"query":"swift actors"}]"#
        let result = builder.extractWebSearchQuery(from: text)
        XCTAssertEqual(result?.query, "swift actors")
        XCTAssertEqual(result?.maxResults, 5)
    }

    func testExtractWebSearchQueryReturnsNilForMalformedJSON() {
        let text = "[WEB_SEARCH:{bad json}]"
        XCTAssertNil(builder.extractWebSearchQuery(from: text))
    }

    func testExtractWebSearchQueryReturnsNilWhenQueryFieldMissing() {
        let text = #"[WEB_SEARCH:{"maxResults":5}]"#
        XCTAssertNil(builder.extractWebSearchQuery(from: text))
    }

    // MARK: - Helpers

    private func promptWithCalendar() async -> String {
        let settings = MockAppSettings()
        settings.calendarAccessEnabled = true
        let b = SystemPromptBuilder(
            calendarService: calendar,
            contextService: MockContextService(),
            settings: settings,
            calendarActionController: MockCalendarActionController()
        )
        return await b.buildSystemPrompt()
    }
}
