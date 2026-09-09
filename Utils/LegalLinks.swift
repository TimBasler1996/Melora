import Foundation

/// Public pages linked from Settings. Leave a value `nil` until the page
/// exists; the row is hidden in that case so nothing links into the void.
enum LegalLinks {
    // Served by Firebase Hosting from the `hosting/` folder (see firebase.json).
    static let privacyPolicy: URL? = URL(string: "https://socialsound-5fdd9.web.app/privacy")
    static let termsOfService: URL? = URL(string: "https://socialsound-5fdd9.web.app/terms")
    static let supportEmail: String? = nil // Set to the address in hosting/privacy.html once decided.

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
