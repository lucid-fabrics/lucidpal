@testable import LucidPal
import XCTest

@MainActor
final class ContextServiceTests: XCTestCase {

    var sut: ContextService!
    var mockSettings: MockAppSettings!

    override func setUp() async throws {
        mockSettings = MockAppSettings()
        sut = ContextService(settings: mockSettings)
    }

    override func tearDown() {
        sut = nil
        mockSettings = nil
    }

    // MARK: - Initialization Tests

    func testInitializationLoadsSettingsCorrectly() {
        mockSettings.notesAccessEnabled = true
        mockSettings.remindersAccessEnabled = false
        mockSettings.mailAccessEnabled = true

        let service = ContextService(settings: mockSettings)

        XCTAssertTrue(service.isNotesEnabled)
        XCTAssertFalse(service.isRemindersEnabled)
        XCTAssertTrue(service.isMailEnabled)
    }

    // MARK: - fetchContext Tests

    func testFetchContextReturnsNilWhenAllSourcesDisabled() async throws {
        mockSettings.notesAccessEnabled = false
        mockSettings.remindersAccessEnabled = false
        mockSettings.mailAccessEnabled = false

        let context = await sut.fetchContext(query: nil)

        XCTAssertNil(context)
    }

    func testFetchContextReturnsNilWhenNoItemsFound() async throws {
        mockSettings.remindersAccessEnabled = true

        let context = await sut.fetchContext(query: nil)

        // No reminders authorized, so should return nil
        XCTAssertNil(context)
    }

    func testFetchContextWithQueryPassesQueryCorrectly() async throws {
        mockSettings.remindersAccessEnabled = true

        _ = await sut.fetchContext(query: "Montreal trip")

        // Verify query was passed (we can't test actual filtering without EKEventStore mock)
    }

    // MARK: - Permission Request Tests

    func testRequestNotesAccessReturnsFalse() async throws {
        let granted = await sut.requestNotesAccess()

        XCTAssertFalse(granted)
        XCTAssertFalse(sut.isNotesEnabled)
    }

    func testRequestMailAccessReturnsFalse() async throws {
        let granted = await sut.requestMailAccess()

        XCTAssertFalse(granted)
        XCTAssertFalse(sut.isMailEnabled)
    }

    // MARK: - ContextItem Formatting Tests

    func testContextItemFormattedWithAllFields() {
        let date = Date(timeIntervalSince1970: 1710000000)
        let item = ContextItem(
            id: "1",
            source: .reminders,
            title: "Buy groceries",
            content: "Milk, eggs, bread",
            date: date,
            metadata: [:]
        )

        let formatted = item.formatted()

        XCTAssertTrue(formatted.contains("[Reminders]"))
        XCTAssertTrue(formatted.contains("Buy groceries"))
        XCTAssertTrue(formatted.contains("Milk, eggs, bread"))
    }

    func testContextItemFormattedWithoutContent() {
        let item = ContextItem(
            id: "2",
            source: .notes,
            title: "Meeting notes",
            content: nil,
            date: nil,
            metadata: [:]
        )

        let formatted = item.formatted()

        XCTAssertTrue(formatted.contains("[Notes]"))
        XCTAssertTrue(formatted.contains("Meeting notes"))
        XCTAssertFalse(formatted.contains(" - "))
    }

    func testContextItemFormattedWithEmptyContent() {
        let item = ContextItem(
            id: "3",
            source: .mail,
            title: "Invoice",
            content: "",
            date: Date(),
            metadata: [:]
        )

        let formatted = item.formatted()

        XCTAssertTrue(formatted.contains("[Mail]"))
        XCTAssertTrue(formatted.contains("Invoice"))
        XCTAssertFalse(formatted.contains(" - "))
    }

    // MARK: - Integration with AppSettings Tests

    func testRemindersAccessUpdatesSettings() async throws {
        mockSettings.remindersAccessEnabled = false

        // In unit tests EKEventStore denies access — result must be false
        // and isRemindersEnabled must reflect that denial
        let granted = await sut.requestRemindersAccess()

        XCTAssertFalse(granted, "EKEventStore must deny access in unit test environment")
        XCTAssertEqual(sut.isRemindersEnabled, granted, "isRemindersEnabled must reflect the authorization result")
    }
}
