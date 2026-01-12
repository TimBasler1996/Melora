import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

final class OnboardingProfileService {

    static let shared = OnboardingProfileService()

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    private init() {}

    func uploadPhotos(uid: String, profile: Data, photo2: Data, photo3: Data) async throws -> [String] {
        let profileURL = try await uploadPhoto(data: profile, path: "users/\(uid)/photos/profile.jpg")
        let secondURL = try await uploadPhoto(data: photo2, path: "users/\(uid)/photos/2.jpg")
        let thirdURL = try await uploadPhoto(data: photo3, path: "users/\(uid)/photos/3.jpg")
        return [profileURL, secondURL, thirdURL]
    }

    func saveUserProfile(uid: String, payload: [String: Any]) async throws {
        try await db.collection("users").document(uid).setData(payload, merge: true)
    }

    func shouldSetCreatedAt(uid: String) async throws -> Bool {
        let snap = try await db.collection("users").document(uid).getDocument()
        guard snap.exists else { return true }
        let data = snap.data()
        return data?["createdAt"] == nil
    }

    private func uploadPhoto(data: Data, path: String) async throws -> String {
        let jpegData = makeJPEGData(from: data)
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(jpegData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        return downloadURL.absoluteString
    }

    private func makeJPEGData(from data: Data) -> Data {
        if let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.9) {
            return jpeg
        }
        return data
    }
}
