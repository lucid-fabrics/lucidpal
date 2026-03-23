import XCTest

@testable import PocketMind

@MainActor
final class SessionManagerTests: XCTestCase {
    var manager: SessionManager!
    private var tempDirectory: URL!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        manager = SessionManager(directory: tempDirectory)
    }

    override func tearDown() async throws {
        manager = nil
        try FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
    }

    // MARK: - loadIndex

    func testLoadIndexEmptyOnInit() {
        XCTAssertTrue(manager.loadIndex().isEmpty)
    }

    // MARK: - save / index (synchronous path — index is updated synchronously)

    func testSaveAppearsInIndex() {
        let session = ChatSession.new()
        manager.save(session)
        XCTAssertTrue(manager.loadIndex().contains { $0.id == session.id })
    }

    func testSaveUpdatesExistingIndexEntry() {
        var session = ChatSession.new()
        manager.save(session)
        session.title = "Updated Title"
        manager.save(session)

        let index = manager.loadIndex()
        XCTAssertEqual(index.filter { $0.id == session.id }.count, 1)
        XCTAssertEqual(index.first { $0.id == session.id }?.title, "Updated Title")
    }

    func testMultipleSessionsAllAppearInIndex() {
        let s1 = ChatSession.new()
        let s2 = ChatSession.new()
        manager.save(s1)
        manager.save(s2)
        let ids = Set(manager.loadIndex().map { $0.id })
        XCTAssertTrue(ids.contains(s1.id))
        XCTAssertTrue(ids.contains(s2.id))
    }

    // MARK: - loadSession (reads from disk — needs background write to settle)

    func testSaveAndLoadSessionRoundTrip() async throws {
        let session = ChatSession(
            id: UUID(), title: "Test", createdAt: .now, updatedAt: .now,
            messages: [ChatMessage(role: .user, content: "hello")]
        )
        await manager.save(session).value

        let loaded = try XCTUnwrap(manager.loadSession(id: session.id))
        XCTAssertEqual(loaded.id, session.id)
        XCTAssertEqual(loaded.title, "Test")
        XCTAssertEqual(loaded.messages.first?.content, "hello")
    }

    func testSaveExcludesSystemMessages() async throws {
        let session = ChatSession(
            id: UUID(), title: "T", createdAt: .now, updatedAt: .now,
            messages: [
                ChatMessage(role: .user, content: "hi"),
                ChatMessage(role: .system, content: "system prompt")
            ]
        )
        await manager.save(session).value

        let loaded = try XCTUnwrap(manager.loadSession(id: session.id))
        XCTAssertFalse(loaded.messages.contains { $0.role == .system })
        XCTAssertEqual(loaded.messages.count, 1)
    }

    func testLoadSessionReturnsNilForUnknownID() {
        XCTAssertNil(manager.loadSession(id: UUID()))
    }

    // MARK: - delete

    func testDeleteRemovesFromIndex() {
        let session = ChatSession.new()
        manager.save(session)
        manager.delete(id: session.id)
        XCTAssertFalse(manager.loadIndex().contains { $0.id == session.id })
    }

    func testDeleteMakesSessionUnloadable() async throws {
        let session = ChatSession.new()
        await manager.save(session).value
        manager.delete(id: session.id)
        XCTAssertNil(manager.loadSession(id: session.id))
    }

    func testDeleteUnknownIDIsNoOp() {
        let session = ChatSession.new()
        manager.save(session)
        manager.delete(id: UUID())
        XCTAssertEqual(manager.loadIndex().count, 1)
    }

    // MARK: - ChatSession.new()

    func testNewSessionHasNewChatTitle() {
        XCTAssertEqual(ChatSession.new().title, "New Chat")
    }

    func testNewSessionHasEmptyMessages() {
        XCTAssertTrue(ChatSession.new().messages.isEmpty)
    }

    func testNewSessionCreatedAtEqualsUpdatedAt() {
        let session = ChatSession.new()
        XCTAssertEqual(session.createdAt.timeIntervalSince1970,
                       session.updatedAt.timeIntervalSince1970,
                       accuracy: 0.01)
    }
}
