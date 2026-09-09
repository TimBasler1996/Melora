import Foundation

/// Simple representation of a geographic location using latitude and longitude.
struct LocationPoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

extension LocationPoint {
    func toDict() -> [String: Any] {
        [
            "latitude": latitude,
            "longitude": longitude
        ]
    }

    static func fromDict(_ dict: [String: Any]) -> LocationPoint? {
        guard
            let lat = dict["latitude"] as? Double,
            let lon = dict["longitude"] as? Double
        else { return nil }

        return LocationPoint(latitude: lat, longitude: lon)
    }

    /// Grid step used before a location leaves the device: 0.0025° is roughly
    /// 275 m north–south, so nobody can pinpoint where a person is standing.
    static let privacyGridDegrees: Double = 0.0025

    /// The point snapped to the privacy grid. Everything written to Firestore
    /// goes through this; the precise fix never leaves the device.
    func fuzzed() -> LocationPoint {
        let g = Self.privacyGridDegrees
        return LocationPoint(
            latitude: (latitude / g).rounded() * g,
            longitude: (longitude / g).rounded() * g
        )
    }
}
