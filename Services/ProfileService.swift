import Foundation
import FirebaseAuth
import FirebaseFirestore
import UIKit

@MainActor
final class ProfileService {
    private let db = Firestore.firestore()
    private let onboardingService = OnboardingProfileService()

    func fetchCurrentUserProfile() async throws -> UserProfile {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No Firebase user."])
        }

        let snapshot = try await db.collection("users").document(uid).getDocument()
        guard let data = snapshot.data() else {
            throw NSError(domain: "Profile", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found."])
        }

        return UserProfile.fromFirestore(uid: uid, data: data)
    }

    func saveBasics(_ basics: OnboardingProfileService.Basics, uid: String) async throws {
        try await onboardingService.saveBasics(basics, uid: uid)
    }

    func savePhotos(photoURLs: [String], uid: String) async throws {
        try await onboardingService.savePhotos(photoURLs: photoURLs, uid: uid)
    }

    func uploadPhoto(image: UIImage, uid: String, index: Int) async throws -> String {
        try await onboardingService.uploadPhoto(image: image, uid: uid, index: index)
    }

    func refreshSpotifyProfile(uid: String) async throws {
        let spotifyProfile = try await SpotifyService.shared.fetchCurrentUserProfile()
        try await onboardingService.saveSpotify(
            spotifyId: spotifyProfile.id,
            countryCode: spotifyProfile.countryCode,
            spotifyAvatarURL: spotifyProfile.imageURL?.absoluteString,
            uid: uid
        )
    }
}
