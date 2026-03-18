import XCTest
@testable import PocketMind

@MainActor
final class ChatHistoryManagerTests: XCTestCase {
    var manager: ChatHistoryManager!

    override func setUp() {
        super.setUp()
        manager = ChatHistoryManager()
        // Clean slate — remove any leftover file from previous test runs
        manager.clear()
    }

    override func tearDown() {
        manager.clear()
        super.tearDown()
    }

    func testLoadReturnsEmptyArrayWhenNoFileExists() {
        let messages = manager.load()
        XCTAssertTrue(messages.isEmpty)
    }

    func testSaveAndLoadRoundTrip() async throws {
        let messages = [
            ChatMessage(role: .user, content: "hello"),
            ChatMessage(role: .assistant, content: "hi there"),
        ]
        manager.save(messages)
        // Allow the detached utility-priority task to complete
        try await Task.sleep(for: .milliseconds(500))

        let loaded = manager.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].content, "hello")
        XCTAssertEqual(loaded[1].content, "hi there")
    }

    func testSaveFiltersSystemMessages() async throws {
        let messages = [
            ChatMessage(role: .system, content: "system prompt"),
            ChatMessage(role: .user, content: "user message"),
        ]
        manager.save(messages)
        try await Task.sleep(for: .milliseconds(500))

        let loaded = manager.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.role, .user)
    }

    func testClearRemovesPersistedMessages() async throws {
        let messages = [ChatMessage(role: .user, content: "test")]
        manager.save(messages)
        try await Task.sleep(for: .milliseconds(500))

        manager.clear()
        let loaded = manager.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testSaveEmptyArrayProducesEmptyLoad() async throws {
        manager.save([])
        try await Task.sleep(for: .milliseconds(500))

        let loaded = manager.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testLoadPreservesMessageRoles() async throws {
        let messages = [
            ChatMessage(role: .user, content: "q"),
            ChatMessage(role: .assistant, content: "a"),
        ]
        manager.save(messages)
        try await Task.sleep(for: .milliseconds(500))

        let loaded = manager.load()
        XCTAssertEqual(loaded[0].role, .user)
        XCTAssertEqual(loaded[1].role, .assistant)
    }
}
