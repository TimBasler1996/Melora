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
}

