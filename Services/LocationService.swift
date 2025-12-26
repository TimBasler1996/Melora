//
//  LocationService.swift
//  SocialSound
//
//  Created by Tim Basler on 14.11.2025.
//


import Foundation
import CoreLocation

/// Wraps CLLocationManager and exposes the user's current location
/// in a SwiftUI-friendly way.
final class LocationService: NSObject, ObservableObject {
    
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var currentLocationPoint: LocationPoint?
    
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }
    
    /// Requests "when in use" authorization if not determined yet.
    func requestAuthorizationIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }
    
    /// Starts location updates if we are authorized.
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
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        startUpdatingIfAuthorized()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let point = LocationPoint(
            latitude: last.coordinate.latitude,
            longitude: last.coordinate.longitude
        )
        currentLocationPoint = point
        // Debug:
        print("📍 Updated location: \(point.latitude), \(point.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location update failed: \(error)")
    }
}
