import Foundation
@testable import PocketMind

@MainActor
final class MockCalendarActionController: CalendarActionControllerProtocol {
    var stubbedResult: CalendarActionResult = .queryResult([])
    private(set) var executeCalled = false
    private(set) var lastJSON: String?

    func execute(json: String) async -> CalendarActionResult {
        executeCalled = true
        lastJSON = json
        return stubbedResult
    }
}
