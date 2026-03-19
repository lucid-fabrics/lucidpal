import XCTest
@testable import PocketMind

@MainActor
final class ChatViewModelSystemPromptTests: XCTestCase {

    var calendar: MockCalendarService!
    var vm: ChatViewModel!

    override func setUp() async throws {
        calendar = MockCalendarService()
        vm = ChatViewModel(
            llmService: MockLLMService(),
            calendarService: calendar,
            calendarActionController: MockCalendarActionController(),
            settings: MockAppSettings(),
            speechService: MockSpeechService(),
            hapticService: MockHapticService(),
            historyManager: NoOpChatHistoryManager()
        )
    }

    // MARK: - actionPattern regex

    func testActionPatternMatchesSimpleCreateBlock() {
        let text = #"[CALENDAR_ACTION:{"action":"create","title":"Meeting"}]"#
        let regex = try? NSRegularExpression(pattern: ChatViewModel.actionPattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex?.matches(in: text, range: range) ?? []
        XCTAssertEqual(matches.count, 1)
    }

    func testActionPatternMatchesMultipleBlocks() {
        let text = #"[CALENDAR_ACTION:{"action":"delete","search":"X"}] ok [CALENDAR_ACTION:{"action":"create","title":"Y"}]"#
        let regex = try? NSRegularExpression(pattern: ChatViewModel.actionPattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex?.matches(in: text, range: range) ?? []
        XCTAssertEqual(matches.count, 2)
    }

    func testActionPatternDoesNotMatchMalformedBlock() {
        let text = "CALENDAR_ACTION no brackets here"
        let regex = try? NSRegularExpression(pattern: ChatViewModel.actionPattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex?.matches(in: text, range: range) ?? []
        XCTAssertEqual(matches.count, 0)
    }

    // MARK: - formattedToday

    func testFormattedTodayIsNonEmpty() {
        XCTAssertFalse(vm.formattedToday().isEmpty)
    }

    func testFormattedTodayContainsCurrentYear() {
        let year = Calendar.current.component(.year, from: Date())
        XCTAssertTrue(vm.formattedToday().contains(String(year)))
    }

    // MARK: - calendarToolInstructions

    func testCalendarToolInstructionsContainsCreateAction() {
        let instructions = vm.calendarToolInstructions()
        XCTAssertTrue(instructions.contains("create"))
    }

    func testCalendarToolInstructionsContainsDeleteAction() {
        let instructions = vm.calendarToolInstructions()
        XCTAssertTrue(instructions.contains("delete"))
    }

    func testCalendarToolInstructionsContainsQueryAction() {
        let instructions = vm.calendarToolInstructions()
        XCTAssertTrue(instructions.contains("query"))
    }

    // MARK: - calendarBlockFormats

    func testCalendarBlockFormatsContainsISO8601Format() {
        let formats = vm.calendarBlockFormats()
        XCTAssertTrue(formats.contains("YYYY-MM-DDTHH:MM:SS"))
    }

    // MARK: - calendarActionRules

    func testCalendarActionRulesContainsMandatoryRule() {
        let rules = vm.calendarActionRules()
        XCTAssertTrue(rules.contains("NEVER skip the block"))
    }

    // MARK: - executeCalendarActions (no-op when no blocks present)

    func testExecuteCalendarActionsPassesThroughPlainText() async {
        let plain = "Hello, here are your events for today."
        let (content, previews, slots) = await vm.executeCalendarActions(in: plain)
        XCTAssertEqual(content, plain)
        XCTAssertTrue(previews.isEmpty)
        XCTAssertTrue(slots.isEmpty)
    }

    // MARK: - buildSystemPrompt (calendar disabled)

    func testBuildSystemPromptContainsTodaysDate() async {
        let settings = MockAppSettings()
        settings.calendarAccessEnabled = false
        let calVM = ChatViewModel(
            llmService: MockLLMService(),
            calendarService: calendar,
            calendarActionController: MockCalendarActionController(),
            settings: settings,
            speechService: MockSpeechService(),
            hapticService: MockHapticService(),
            historyManager: NoOpChatHistoryManager()
        )
        let prompt = await calVM.buildSystemPrompt()
        let year = String(Calendar.current.component(.year, from: Date()))
        XCTAssertTrue(prompt.contains(year))
    }

    func testBuildSystemPromptWithCalendarDisabledOmitsToolInstructions() async {
        let settings = MockAppSettings()
        settings.calendarAccessEnabled = false
        let calVM = ChatViewModel(
            llmService: MockLLMService(),
            calendarService: calendar,
            calendarActionController: MockCalendarActionController(),
            settings: settings,
            speechService: MockSpeechService(),
            hapticService: MockHapticService(),
            historyManager: NoOpChatHistoryManager()
        )
        let prompt = await calVM.buildSystemPrompt()
        XCTAssertFalse(prompt.contains("CALENDAR TOOL"))
    }
}
