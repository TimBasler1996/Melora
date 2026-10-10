import Foundation

/// How far away someone is, in bands rather than numbers.
///
/// Positions are fuzzed to a ~275 m grid before they are ever shared, so a
/// precise figure would be false precision as well as an intrusion. Lives
/// apart from the views because three screens render it and because this is
/// the kind of rule that has to stay testable.
enum DistanceFormat {

    /// A coarse band: "under 500 m", "about 2 km".
    static func band(_ meters: Int) -> String {
        if meters < 500 { return "under 500 m" }
        if meters < 1000 { return "under 1 km" }
        let km = Double(meters) / 1000.0
        if km < 10 {
            let half = (km * 2).rounded() / 2
            return half == half.rounded() ? "about \(Int(half)) km" : String(format: "about %.1f km", half)
        }
        return "about \(Int(km.rounded())) km"
    }

    /// Whole kilometres, for copy that names one distance ("the nearest
    /// about 40 km"). Never returns "0 km".
    static func coarseKilometres(_ meters: Int) -> String {
        meters < 1000 ? "1 km" : "\(Int((Double(meters) / 1000).rounded())) km"
    }
}
