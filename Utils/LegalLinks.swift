import Foundation

/// Public pages linked from Settings. Leave a value `nil` until the page
/// exists; the row is hidden in that case so nothing links into the void.
enum LegalLinks {
    static let privacyPolicy: URL? = nil   // e.g. URL(string: "https://melora.app/privacy")
    static let termsOfService: URL? = nil  // e.g. URL(string: "https://melora.app/terms")
    static let supportEmail: String? = nil // e.g. "hello@melora.app"

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
