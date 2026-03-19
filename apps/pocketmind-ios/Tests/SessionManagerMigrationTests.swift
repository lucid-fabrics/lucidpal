import XCTest
@testable import PocketMind

/// Tests SessionManager's persistence behaviour and legacy chat_history.json migration path.
@MainActor
final class SessionManagerMigrationTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
    }

    // MARK: - Fresh-directory behaviour

    func testMigrationSkippedWhenNoLegacyFile() {
        // No chat_history.json in temp dir — init should succeed cleanly
        let manager = SessionManager(directory: tempDirectory)
        XCTAssertTrue(manager.loadIndex().isEmpty,
                      "Fresh directory with no legacy file should start empty")
    }

    // MARK: - Save & load round-trip

    func testNewSessionsCanBeSavedAfterInit() async throws {
        let manager = SessionManager(directory: tempDirectory)
        let session = ChatSession.new()
        await manager.save(session).value
        XCTAssertTrue(manager.loadIndex().contains { $0.id == session.id })
    }

    func testSessionsPersistAcrossManagerInstances() async throws {
        let session = ChatSession(
            id: UUID(), title: "Persistent", createdAt: .now, updatedAt: .now,
            messages: [ChatMessage(role: .user, content: "persist me")]
        )
        let manager1 = SessionManager(directory: tempDirectory)
        await manager1.save(session).value

        let manager2 = SessionManager(directory: tempDirectory)
        let loaded = manager2.loadSession(id: session.id)
        XCTAssertEqual(loaded?.title, "Persistent")
        XCTAssertEqual(loaded?.messages.first?.content, "persist me")
    }

    // MARK: - Index ordering

    /// updateIndex inserts new sessions at position 0, so the most-recently saved session
    /// appears first — regardless of createdAt/updatedAt dates.
    func testIndexOrderIsMostRecentlySavedFirst() async throws {
        let manager = SessionManager(directory: tempDirectory)
        let old = ChatSession(id: UUID(), title: "Old", createdAt: .distantPast, updatedAt: .distantPast, messages: [])
        let new = ChatSession(id: UUID(), title: "New", createdAt: .now, updatedAt: .now, messages: [])
        // Save old first, then new — new will be inserted at head
        await manager.save(old).value
        await manager.save(new).value
        let index = manager.loadIndex()
        XCTAssertEqual(index.first?.title, "New",
                       "Most recently saved session should appear first in the index")
    }

    // MARK: - Delete

    func testDeleteRemovesSessionFromIndex() async throws {
        let manager = SessionManager(directory: tempDirectory)
        let session = ChatSession.new()
        await manager.save(session).value
        manager.delete(id: session.id)
        XCTAssertFalse(manager.loadIndex().contains { $0.id == session.id })
    }

    func testDeletedSessionFileIsRemoved() async throws {
        let manager = SessionManager(directory: tempDirectory)
        let session = ChatSession.new()
        await manager.save(session).value
        manager.delete(id: session.id)
        XCTAssertNil(manager.loadSession(id: session.id))
    }

    // MARK: - Rename

    func testRenameSessionUpdatesTitle() async throws {
        let manager = SessionManager(directory: tempDirectory)
        var session = ChatSession.new()
        session.title = "Original"
        await manager.save(session).value
        await manager.renameSession(id: session.id, title: "Renamed").value
        let loaded = manager.loadSession(id: session.id)
        XCTAssertEqual(loaded?.title, "Renamed")
    }

    // MARK: - System message filtering

    func testSystemMessagesAreNotPersisted() async throws {
        let manager = SessionManager(directory: tempDirectory)
        let messages: [ChatMessage] = [
            ChatMessage(role: .system, content: "You are a helpful assistant."),
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi there")
        ]
        let session = ChatSession(id: UUID(), title: "Test", createdAt: .now, updatedAt: .now, messages: messages)
        await manager.save(session).value
        let loaded = manager.loadSession(id: session.id)
        XCTAssertFalse(loaded?.messages.contains { $0.role == .system } ?? false,
                       "System messages should be stripped before persistence")
        XCTAssertEqual(loaded?.messages.count, 2)
    }
}
