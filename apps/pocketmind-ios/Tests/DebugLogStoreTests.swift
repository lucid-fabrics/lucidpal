import XCTest

@testable import PocketMind

@MainActor
final class DebugLogStoreTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        DebugLogStore.shared.clear()
    }

    override func tearDown() async throws {
        DebugLogStore.shared.clear()
        try await super.tearDown()
    }

    // MARK: - Append

    func testLogAppendsEntry() {
        DebugLogStore.shared.log("msg", category: "cat")

        XCTAssertEqual(DebugLogStore.shared.entries.count, 1)
        XCTAssertEqual(DebugLogStore.shared.entries[0].message, "msg")
    }

    // MARK: - Category and level

    func testLogDefaultLevelIsInfo() {
        DebugLogStore.shared.log("info message", category: "TestCat")

        XCTAssertEqual(DebugLogStore.shared.entries[0].level, .info)
        XCTAssertEqual(DebugLogStore.shared.entries[0].category, "TestCat")
    }

    func testLogExplicitErrorLevel() {
        DebugLogStore.shared.log("error message", category: "TestCat", level: .error)

        XCTAssertEqual(DebugLogStore.shared.entries[0].level, .error)
    }

    func testLogExplicitWarningLevel() {
        DebugLogStore.shared.log("warn message", category: "TestCat", level: .warning)

        XCTAssertEqual(DebugLogStore.shared.entries[0].level, .warning)
    }

    // MARK: - Clear

    func testClearRemovesAllEntries() {
        DebugLogStore.shared.log("a", category: "c")
        DebugLogStore.shared.log("b", category: "c")
        DebugLogStore.shared.log("c", category: "c")

        DebugLogStore.shared.clear()

        XCTAssertTrue(DebugLogStore.shared.entries.isEmpty)
    }

    // MARK: - Cap

    func testMaxEntriesCapIsRespected() {
        for i in 0..<501 {
            DebugLogStore.shared.log("entry \(i)", category: "cap")
        }

        XCTAssertEqual(DebugLogStore.shared.entries.count, 500)
    }

    func testOldestEntryRemovedWhenCapExceeded() {
        // Log 500 entries first
        for i in 0..<500 {
            DebugLogStore.shared.log("entry \(i)", category: "cap")
        }
        // Log the 501st entry — this should evict "entry 0"
        DebugLogStore.shared.log("new", category: "cap")

        XCTAssertEqual(DebugLogStore.shared.entries.count, 500)
        XCTAssertEqual(DebugLogStore.shared.entries[0].message, "entry 1")
        XCTAssertEqual(DebugLogStore.shared.entries.last?.message, "new")
    }

    // MARK: - Date

    func testEntryHasRecentDate() {
        let before = Date()
        DebugLogStore.shared.log("dated", category: "d")
        let after = Date()

        let entryDate = DebugLogStore.shared.entries[0].date
        XCTAssertGreaterThanOrEqual(entryDate, before)
        XCTAssertLessThanOrEqual(entryDate, after)
    }

    // MARK: - Unique ID

    func testTwoEntriesHaveDifferentIDs() {
        DebugLogStore.shared.log("first", category: "id")
        DebugLogStore.shared.log("second", category: "id")

        let ids = DebugLogStore.shared.entries.map(\.id)
        XCTAssertNotEqual(ids[0], ids[1])
    }
}
