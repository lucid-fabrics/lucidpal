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

    // MARK: - formattedToday

    func testFormattedTodayIsNonEmpty() {
        XCTAssertFalse(builder.formattedToday().isEmpty)
    }

    func testFormattedTodayContainsCurrentYear() {
        let year = Calendar.current.component(.year, from: Date())
        XCTAssertTrue(builder.formattedToday().contains(String(year)))
    }

    // MARK: - calendarToolInstructions

    func testCalendarToolInstructionsContainsCreateAction() {
        XCTAssertTrue(builder.calendarToolInstructions().contains("create"))
    }

    func testCalendarToolInstructionsContainsDeleteAction() {
        XCTAssertTrue(builder.calendarToolInstructions().contains("delete"))
    }

    func testCalendarToolInstructionsContainsQueryAction() {
        XCTAssertTrue(builder.calendarToolInstructions().contains("query"))
    }

    // MARK: - calendarBlockFormats

    func testCalendarBlockFormatsContainsISO8601Format() {
        XCTAssertTrue(builder.calendarBlockFormats().contains("YYYY-MM-DDTHH:MM:SS"))
    }

    // MARK: - calendarActionRules

    func testCalendarActionRulesContainsMandatoryRule() {
        XCTAssertTrue(builder.calendarActionRules().contains("NEVER skip the block"))
    }

    // MARK: - executeCalendarActions (no-op when no blocks present)

    func testExecuteCalendarActionsPassesThroughPlainText() async {
        let plain = "Hello, here are your events for today."
        let (content, previews, slots) = await builder.executeCalendarActions(in: plain)
        XCTAssertEqual(content, plain)
        XCTAssertTrue(previews.isEmpty)
        XCTAssertTrue(slots.isEmpty)
    }

    // MARK: - buildSystemPrompt (calendar disabled)

    func testBuildSystemPromptContainsTodaysDate() async {
        let settings = MockAppSettings()
        settings.calendarAccessEnabled = false
        let b = SystemPromptBuilder(
            calendarService: calendar,
            contextService: MockContextService(),
            settings: settings,
            calendarActionController: MockCalendarActionController()
        )
        let prompt = await b.buildSystemPrompt()
        let year = String(Calendar.current.component(.year, from: Date()))
        XCTAssertTrue(prompt.contains(year))
    }

    func testBuildSystemPromptWithCalendarDisabledOmitsToolInstructions() async {
        let settings = MockAppSettings()
        settings.calendarAccessEnabled = false
        let b = SystemPromptBuilder(
            calendarService: calendar,
            contextService: MockContextService(),
            settings: settings,
            calendarActionController: MockCalendarActionController()
        )
        let prompt = await b.buildSystemPrompt()
        XCTAssertFalse(prompt.contains("CALENDAR TOOL"))
    }
}
