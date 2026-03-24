@testable import PocketMind
import XCTest

@MainActor
final class ChatHistoryManagerTests: XCTestCase {
    var manager: ChatHistoryManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = ChatHistoryManager()
        // Clean slate — remove any leftover file from previous test runs (file may not exist)
        try? FileManager.default.removeItem(at: ChatHistoryManager.historyURL)
    }

    override func tearDown() async throws {
        if FileManager.default.fileExists(atPath: ChatHistoryManager.historyURL.path) {
            try FileManager.default.removeItem(at: ChatHistoryManager.historyURL)
        }
        manager = nil
        try await super.tearDown()
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
        await manager.save(messages).value

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
        await manager.save(messages).value

        let loaded = manager.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.role, .user)
    }

    func testClearRemovesPersistedMessages() async throws {
        let messages = [ChatMessage(role: .user, content: "test")]
        await manager.save(messages).value

        manager.clear()
        let loaded = manager.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testSaveEmptyArrayProducesEmptyLoad() async throws {
        await manager.save([]).value

        let loaded = manager.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testLoadPreservesMessageRoles() async throws {
        let messages = [
            ChatMessage(role: .user, content: "q"),
            ChatMessage(role: .assistant, content: "a"),
        ]
        await manager.save(messages).value

        let loaded = manager.load()
        XCTAssertEqual(loaded[0].role, .user)
        XCTAssertEqual(loaded[1].role, .assistant)
    }

    func testLoadReturnsFallbackWhenFileMalformed() throws {
        try Data("not valid json {{{".utf8).write(to: ChatHistoryManager.historyURL)
        let messages = manager.load()
        XCTAssertTrue(messages.isEmpty)
    }

    func testSavePreservesMessageIDs() async throws {
        let msg = ChatMessage(role: .user, content: "identify me")
        await manager.save([msg]).value
        let loaded = manager.load()
        XCTAssertEqual(loaded.first?.id, msg.id)
    }

    func testSaveOverwritesPreviousHistory() async throws {
        await manager.save([ChatMessage(role: .user, content: "first")]).value
        await manager.save([ChatMessage(role: .user, content: "second")]).value
        let loaded = manager.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].content, "second")
    }

    func testSaveOnlySystemMessagesWritesEmptyFile() async throws {
        await manager.save([ChatMessage(role: .system, content: "sys")]).value
        XCTAssertTrue(manager.load().isEmpty)
    }

    func testClearIsIdempotentWhenFileAbsent() {
        // setUp already removed the file — calling clear twice must not crash
        manager.clear()
        manager.clear()
    }

    func testLoadReturnsFallbackWhenFileBinaryGarbage() throws {
        let garbage = Data((0..<256).map { _ in UInt8.random(in: 0...255) })
        try garbage.write(to: ChatHistoryManager.historyURL)
        let messages = manager.load()
        XCTAssertTrue(messages.isEmpty, "Binary garbage should produce empty fallback")
    }

    func testLoadReturnsFallbackWhenFileIsEmptyJSON() throws {
        try Data("{}".utf8).write(to: ChatHistoryManager.historyURL)
        let messages = manager.load()
        XCTAssertTrue(messages.isEmpty, "Empty JSON object should produce empty fallback")
    }

    // MARK: - NoOpChatHistoryManager

    func testNoOpLoadAlwaysReturnsEmpty() {
        let noOp = NoOpChatHistoryManager()
        XCTAssertTrue(noOp.load().isEmpty)
    }

    func testNoOpSaveDoesNotPersistToDisk() async {
        let noOp = NoOpChatHistoryManager()
        await noOp.save([ChatMessage(role: .user, content: "x")]).value
        // A fresh ChatHistoryManager should still find nothing
        XCTAssertTrue(manager.load().isEmpty)
    }

    func testNoOpClearDoesNotCrash() {
        let noOp = NoOpChatHistoryManager()
        noOp.clear()
    }
}
