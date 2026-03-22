import CoreLocation
@testable import PocketMind

@MainActor
final class MockLocationService: LocationServiceProtocol {
    var isAuthorized: Bool = false
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var stubbedCity: String? = nil

    func requestCity() async -> String? {
        stubbedCity
    }
}
