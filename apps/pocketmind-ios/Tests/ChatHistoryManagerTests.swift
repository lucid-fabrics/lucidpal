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

    func testSaveAndLoadRoundTrip() {
        let messages = [
            ChatMessage(role: .user, content: "hello"),
            ChatMessage(role: .assistant, content: "hi there"),
        ]
        manager.save(messages)
        // Give background task time to write
        let exp = expectation(description: "file written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        let loaded = manager.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].content, "hello")
        XCTAssertEqual(loaded[1].content, "hi there")
    }

    func testSaveFiltersSystemMessages() {
        let messages = [
            ChatMessage(role: .system, content: "system prompt"),
            ChatMessage(role: .user, content: "user message"),
        ]
        manager.save(messages)
        let exp = expectation(description: "file written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        let loaded = manager.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.role, .user)
    }

    func testClearRemovesPersistedMessages() {
        let messages = [ChatMessage(role: .user, content: "test")]
        manager.save(messages)
        let exp = expectation(description: "file written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        manager.clear()
        let loaded = manager.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testSaveEmptyArrayProducesEmptyLoad() {
        manager.save([])
        let exp = expectation(description: "file written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        let loaded = manager.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testLoadPreservesMessageRoles() {
        let messages = [
            ChatMessage(role: .user, content: "q"),
            ChatMessage(role: .assistant, content: "a"),
        ]
        manager.save(messages)
        let exp = expectation(description: "file written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        let loaded = manager.load()
        XCTAssertEqual(loaded[0].role, .user)
        XCTAssertEqual(loaded[1].role, .assistant)
    }
}
