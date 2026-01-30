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
    
    /// Calculate distance to another location using the Haversine formula.
    /// - Parameter other: The other location point
    /// - Returns: Distance in meters
    func distance(to other: LocationPoint) -> Double {
        let earthRadiusMeters = 6371000.0
        
        let lat1Rad = latitude * .pi / 180
        let lat2Rad = other.latitude * .pi / 180
        let deltaLatRad = (other.latitude - latitude) * .pi / 180
        let deltaLonRad = (other.longitude - longitude) * .pi / 180
        
        let a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLonRad / 2) * sin(deltaLonRad / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadiusMeters * c
    }
}

