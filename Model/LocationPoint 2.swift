import Foundation

struct LocationPoint: Codable, Equatable {
    var lat: Double
    var lng: Double
    
    func toDict() -> [String: Any] {
        ["lat": lat, "lng": lng]
    }
    
    static func fromDict(_ dict: [String: Any]) -> LocationPoint? {
        guard let lat = dict["lat"] as? Double,
              let lng = dict["lng"] as? Double else { return nil }
        return LocationPoint(lat: lat, lng: lng)
    }
}
