import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

@MainActor
final class ProfileSetupWizardViewModel: ObservableObject {
    
    // MARK: - Step State
    
    enum Step: Int, CaseIterable {
        case basics = 1
        case photos = 2
        case finish = 3
    }
    
    @Published var step: Step = .basics
    
    // MARK: - Basics
    
    @Published var displayName: String = ""
    @Published var ageString: String = ""
    @Published var hometown: String = ""
    @Published var musicTaste: String = ""
    
    /// Spotify avatar (optional) – wird im Wizard nur angezeigt, nicht zwingend gespeichert
    @Published var avatarURL: String?
    
    // MARK: - Photos (local picked)
    
    /// 0..2 Bilder, mindestens 2 nötig
    @Published var selectedImages: [UIImage?] = [nil, nil, nil]
    
    // MARK: - UI/Status
    
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    
    /// Wird manchmal in Views für `.id(vm.seed)` verwendet um die UI zu refreshen
    @Published var seed: String = UUID().uuidString
    
    // MARK: - Derived
    
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
    
    // MARK: - Actions
    
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
    
    /// Step 1: Basics speichern (Firestore merge)
    func saveStep1Basics() async throws {
        guard let uid else { throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No Firebase user"]) }
        
        let db = Firestore.firestore()
        var data: [String: Any] = [
            "displayName": displayName,
            "hometown": hometown,
            "musicTaste": musicTaste,
            "updatedAt": Timestamp(date: Date()),
            "lastActiveAt": Timestamp(date: Date())
        ]
        if let ageInt { data["age"] = ageInt }
        if let avatarURL { data["avatarURL"] = avatarURL }
        
        try await db.collection("users").document(uid).setData(data, merge: true)
    }
    
    /// Step 2: Mindestens 2 Bilder hochladen → photoURLs speichern
    func saveStep2UploadPhotos() async throws {
        guard let uid else { throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No Firebase user"]) }
        
        let images = selectedImages.compactMap { $0 }
        guard images.count >= 2 else {
            throw NSError(domain: "Photos", code: 400, userInfo: [NSLocalizedDescriptionKey: "Need at least 2 photos"])
        }
        
        let storage = Storage.storage()
        let db = Firestore.firestore()
        
        var urls: [String] = []
        urls.reserveCapacity(images.count)
        
        for img in images.prefix(3) {
            guard let data = img.jpegData(compressionQuality: 0.85) else { continue }
            let name = UUID().uuidString + ".jpg"
            let path = "userPhotos/\(uid)/\(name)"
            let ref = storage.reference().child(path)
            
            _ = try await ref.putDataAsync(data, metadata: nil)
            let downloadURL = try await ref.downloadURL()
            urls.append(downloadURL.absoluteString)
        }
        
        try await db.collection("users").document(uid).setData([
            "photoURLs": urls,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
    }
    
    /// Step 3: Profil abschliessen
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
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

