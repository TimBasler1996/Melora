import Foundation
import FirebaseAuth
import FirebaseFirestore

/// User reports land in `reports/{id}`; the `onReportCreated` Cloud Function
/// logs them for review. Reporters can write, nobody can read (rules).
final class ReportService {

    static let shared = ReportService()
    private init() {}

    enum Reason: String, CaseIterable, Identifiable {
        case spam
        case inappropriatePhotos = "inappropriate_photos"
        case harassment
        case fakeProfile = "fake_profile"
        case underage
        case other

        var id: String { rawValue }

        var label: String {
            switch self {
            case .spam: return "Spam or scam"
            case .inappropriatePhotos: return "Inappropriate photos"
            case .harassment: return "Harassment or hate"
            case .fakeProfile: return "Fake profile"
            case .underage: return "Seems underage"
            case .other: return "Something else"
            }
        }
    }

    func report(userId: String, reason: Reason, details: String?) async throws {
        guard let reporterId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Report", code: 401, userInfo: [NSLocalizedDescriptionKey: "You’re not signed in."])
        }
        let trimmed = (details ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        try await Firestore.firestore().collection("reports").document().setData([
            "reporterId": reporterId,
            "reportedUserId": userId,
            "reason": reason.rawValue,
            "details": String(trimmed.prefix(500)),
            "createdAt": FieldValue.serverTimestamp()
        ])
    }
}
