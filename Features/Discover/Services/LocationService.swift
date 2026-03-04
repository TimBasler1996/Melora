import Foundation
import CoreLocation

/// Wraps CLLocationManager and exposes the user's current location
/// in a SwiftUI-friendly way.
final class LocationService: NSObject, ObservableObject {

    // MARK: - Published state (updated on main thread)

    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var currentLocationPoint: LocationPoint?

    /// ✅ Alias for older code (NowPlayingView expects this)
    var currentLocation: LocationPoint? { currentLocationPoint }

    private let manager: CLLocationManager

    // ✅ Make sure init is accessible (not private)
    override init() {
        self.manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Public API

    /// Requests "when in use" authorization if not determined yet.
    func requestAuthorizationIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    /// ✅ Alias if some files call it differently
    func requestPermission() {
        requestAuthorizationIfNeeded()
    }

    // MARK: - Internals

    private func startUpdatingIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            manager.stopUpdatingLocation()
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {

    // Swift 6-safe: delegate callbacks are not main-actor isolated.
    // We hop to main when mutating @Published.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = status
        }
        startUpdatingIfAuthorized()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let point = LocationPoint(latitude: last.coordinate.latitude,
                                  longitude: last.coordinate.longitude)

        DispatchQueue.main.async { [weak self] in
            self?.currentLocationPoint = point
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location update failed: \(error)")
    }
}

