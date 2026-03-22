import CoreLocation
import Foundation
import OSLog

private let locationLogger = Logger(subsystem: "app.pocketmind", category: "Location")

// MARK: - Protocol

@MainActor
protocol LocationServiceProtocol: AnyObject {
    var isAuthorized: Bool { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestCity() async -> String?
}

// MARK: - Implementation

@MainActor
final class LocationService: NSObject, LocationServiceProtocol {

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Requests location permission if needed, then resolves city via reverse geocoding.
    func requestCity() async -> String? {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            let status = await withCheckedContinuation { (cont: CheckedContinuation<CLAuthorizationStatus, Never>) in
                authContinuation = cont
            }
            guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                locationLogger.warning("📍 Permission denied")
                return nil
            }
        }
        guard isAuthorized else {
            locationLogger.warning("📍 Location not authorized (status: \(self.authorizationStatus.rawValue))")
            return nil
        }
        let location = await withCheckedContinuation { (cont: CheckedContinuation<CLLocation?, Never>) in
            locationContinuation = cont
            manager.requestLocation()
        }
        guard let location else { return nil }
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let city = placemarks.first?.locality ?? placemarks.first?.administrativeArea
            locationLogger.info("📍 Resolved city: \(city ?? "nil", privacy: .public)")
            return city
        } catch {
            locationLogger.error("📍 Geocoding failed: \(error)")
            return nil
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        locationLogger.info("📍 Auth changed: \(status.rawValue)")
        Task { @MainActor in
            authContinuation?.resume(returning: status)
            authContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locationContinuation?.resume(returning: locations.first)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationLogger.error("📍 Location error: \(error)")
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }
}
