import Foundation
import CoreLocation

/// View model for the "Nearby" screen.
/// Loads active sessions from SessionApiService and resolves the user's
/// coarse location into a human-readable place name.
@MainActor
final class NearbyViewModel: ObservableObject {

    @Published var sessions: [Session] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// Human-readable place for the header, e.g. "Schwabing, Munich".
    /// `nil` while resolving; falls back to "Nearby" when geocoding is unavailable.
    @Published var locationLabel: String?

    private let sessionService = SessionApiService.shared
    private let geocoder = CLGeocoder()

    /// The coordinate we last reverse-geocoded, so we don't re-hit CLGeocoder
    /// (which is strictly rate-limited) on every minor location update.
    private var lastGeocodedLocation: LocationPoint?

    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// Triggers loading nearby sessions with an optional location.
    func loadNearbySessions(location: LocationPoint?) {
        Task {
            await load(location: location)
        }
        resolvePlaceName(for: location)
    }

    private func load(location: LocationPoint?) async {
        isLoading = true
        errorMessage = nil

        let loc = location ?? LocationPoint(latitude: 47.0, longitude: 8.0)

        do {
            let result = try await sessionService.fetchNearbySessions(around: loc)
            // Sort closest-first so the "Closest to you · Distance" header is honest.
            self.sessions = result.sorted { lhs, rhs in
                distance(from: loc, to: lhs.location) < distance(from: loc, to: rhs.location)
            }
        } catch {
            print("❌ Failed to load nearby sessions: \(error)")
            self.errorMessage = "Failed to load nearby sessions."
        }

        isLoading = false
    }

    // MARK: - Reverse geocoding

    /// Resolves a coordinate into a "Neighborhood, City" style label. Never
    /// exposes raw coordinates — falls back to "Nearby" if anything is missing.
    private func resolvePlaceName(for location: LocationPoint?) {
        guard !isRunningInPreview else {
            locationLabel = "Nearby"
            return
        }
        guard let location else {
            locationLabel = nil // still waiting for a fix
            return
        }

        // Throttle: only geocode the first fix, or after the user has moved a
        // meaningful distance (>500 m). CLGeocoder rate-limits aggressively and
        // starts failing if called on every location update.
        if let last = lastGeocodedLocation, locationLabel != nil {
            let moved = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude))
            if moved < 500 { return }
        }
        lastGeocodedLocation = location

        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        Task {
            let placemarks = try? await geocoder.reverseGeocodeLocation(clLocation)
            guard let placemark = placemarks?.first else {
                self.locationLabel = "Nearby"
                return
            }

            let neighborhood = placemark.subLocality
            let city = placemark.locality ?? placemark.administrativeArea

            let parts = [neighborhood, city]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            self.locationLabel = parts.isEmpty ? "Nearby" : parts.joined(separator: ", ")
        }
    }

    private func distance(from a: LocationPoint, to b: LocationPoint) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
