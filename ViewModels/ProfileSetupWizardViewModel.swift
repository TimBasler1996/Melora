import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

@MainActor
final class ProfileSetupWizardViewModel: ObservableObject {

    enum Step: Int, CaseIterable {
        case basics = 1
        case photos = 2
        case finish = 3
    }

    @Published var step: Step = .basics

    // Basics
    @Published var displayName: String = ""
    @Published var ageString: String = ""
    @Published var hometown: String = ""
    @Published var musicTaste: String = ""
    @Published var avatarURL: String? // Spotify avatar optional (wizard zeigt es nur)

    // Photos
    @Published var selectedImages: [UIImage?] = [nil, nil, nil]

    // UI state
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var seed: String = UUID().uuidString

    var canContinueBasics: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canContinuePhotos: Bool {
        selectedImages.compactMap { $0 }.count >= 2
    }

    var canFinish: Bool {
        canContinueBasics && canContinuePhotos && !isSaving
    }

    private var ageInt: Int? {
        let t = ageString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return Int(t)
    }

    private var uid: String? { Auth.auth().currentUser?.uid }

    // MARK: - Navigation

    func goNext() {
        switch step {
        case .basics:
            if canContinueBasics { step = .photos }
        case .photos:
            if canContinuePhotos { step = .finish }
        case .finish:
            break
        }
    }

    func goBack() {
        switch step {
        case .basics:
            break
        case .photos:
            step = .basics
        case .finish:
            step = .photos
        }
    }

    // MARK: - Photo helpers

    func pickPhoto(at index: Int, image: UIImage?) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages[index] = image
        seed = UUID().uuidString
    }

    func removePhoto(at index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages[index] = nil
        seed = UUID().uuidString
    }

    // MARK: - Save Step 1

    func saveStep1Basics() async throws {
        guard let uid else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No Firebase user"])
        }

        let db = Firestore.firestore()
        var data: [String: Any] = [
            "displayName": displayName,
            "hometown": hometown,
            "musicTaste": musicTaste,
            "updatedAt": Timestamp(date: Date()),
            "lastActiveAt": Timestamp(date: Date())
        ]

        if let ageInt { data["age"] = ageInt }
        if let avatarURL { data["avatarURL"] = avatarURL } // Spotify avatar optional

        try await db.collection("users").document(uid).setData(data, merge: true)
    }

    // MARK: - Save Step 2 (Upload) + Fix B

    func saveStep2UploadPhotos() async throws {
        guard let uid else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No Firebase user"])
        }

        let images = selectedImages.compactMap { $0 }
        guard images.count >= 2 else {
            throw NSError(domain: "Photos", code: 400, userInfo: [NSLocalizedDescriptionKey: "Need at least 2 photos"])
        }

        let storage = Storage.storage()
        let db = Firestore.firestore()

        var urls: [String] = []
        urls.reserveCapacity(min(images.count, 3))

        for img in images.prefix(3) {
            guard let data = img.jpegData(compressionQuality: 0.85) else { continue }
            let name = UUID().uuidString + ".jpg"
            let path = "userPhotos/\(uid)/\(name)"
            let ref = storage.reference().child(path)

            _ = try await ref.putDataAsync(data, metadata: nil)
            let downloadURL = try await ref.downloadURL()
            urls.append(downloadURL.absoluteString)
        }

        // ✅ FIX B:
        // - photoURLs speichern
        // - avatarURL auf erstes Upload Bild setzen (primary)
        // - avatarSource auf "uploaded"
        try await db.collection("users").document(uid).setData([
            "photoURLs": urls,
            "avatarURL": urls.first as Any,
            "avatarSource": "uploaded",
            "updatedAt": Timestamp(date: Date()),
            "lastActiveAt": Timestamp(date: Date())
        ], merge: true)
    }

    // MARK: - Finish

    func finishOnboarding() async {
        errorMessage = nil
        guard canFinish else { return }
        guard uid != nil else {
            errorMessage = "No Firebase user."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await saveStep1Basics()
            try await saveStep2UploadPhotos()

            let db = Firestore.firestore()
            try await db.collection("users").document(uid!).setData([
                "profileCompleted": true,
                "updatedAt": Timestamp(date: Date()),
                "lastActiveAt": Timestamp(date: Date())
            ], merge: true)

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

