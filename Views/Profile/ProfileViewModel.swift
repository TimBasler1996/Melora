import Foundation
import FirebaseAuth
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - UI State

    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var saveSucceeded: Bool = false
    @Published var errorMessage: String?

    // MARK: - Profile Data

    @Published var profile: UserProfile?

    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var city: String = ""
    @Published var birthday: Date = Date()
    @Published var gender: String = ""

    /// URLs aus Firestore (kann 0...6 enthalten)
    @Published var photoURLs: [String] = []

    /// Lokale Änderungen (immer 6 Slots, nil = unverändert/leer)
    @Published var selectedImages: [UIImage?] = Array(repeating: nil, count: 6)

    // MARK: - Spotify

    @Published var isRefreshingSpotify: Bool = false

    // MARK: - Services

    private let profileService: ProfileService

    // MARK: - Soft discard snapshot (lokal)

    private var snapshot: Snapshot?

    private struct Snapshot {
        let firstName: String
        let lastName: String
        let city: String
        let birthday: Date
        let gender: String
        let photoURLs: [String]
        let profile: UserProfile?
    }

    // MARK: - Computed

    var ageText: String {
        birthday.age().map(String.init) ?? ""
    }

    var hasChanges: Bool {
        guard let profile else { return false }

        let basicsChanged =
            firstName != profile.firstName ||
            lastName != profile.lastName ||
            city != profile.city ||
            gender != profile.gender ||
            birthday != (profile.birthday ?? birthday)

        let photosChanged = selectedImages.contains { $0 != nil }
        return basicsChanged || photosChanged
    }

    // MARK: - Initializers

    init() {
        self.profileService = ProfileService()
    }

    /// Preview / Testing init (kein Firebase Call)
    init(preview: Bool) {
        self.profileService = ProfileService()
        guard preview else { return }

        let mock = UserProfile.mockPreview
        applyProfile(mock)
    }

    // MARK: - Loading

    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        saveSucceeded = false

        do {
            let fetchedProfile = try await profileService.fetchCurrentUserProfile()
            applyProfile(fetchedProfile)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Photos

    func setSelectedImage(_ image: UIImage?, index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages[index] = image
    }

    /// Soft delete: setzt Slot lokal zurück (später beim Save wird URL ggf. gelöscht/überschrieben)
    func clearSelectedImage(at index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages[index] = nil
    }

    // MARK: - Discard (soft)

    func discardChanges() {
        guard let snapshot else { return }

        self.firstName = snapshot.firstName
        self.lastName = snapshot.lastName
        self.city = snapshot.city
        self.birthday = snapshot.birthday
        self.gender = snapshot.gender
        self.photoURLs = snapshot.photoURLs
        self.profile = snapshot.profile

        self.selectedImages = Array(repeating: nil, count: 6)
        self.saveSucceeded = false
        self.errorMessage = nil
    }

    // MARK: - Saving

    func saveChanges() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "No Firebase user."
            return
        }

        isSaving = true
        saveSucceeded = false
        errorMessage = nil

        do {
            let basics = OnboardingProfileService.Basics(
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                birthday: birthday,
                gender: gender.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            try await profileService.saveBasics(basics, uid: uid)

            // Fotos: wir arbeiten mit 6 Slots
            if selectedImages.contains(where: { $0 != nil }) {
                var updatedPhotoURLs = photoURLs

                if updatedPhotoURLs.count < 6 {
                    updatedPhotoURLs.append(contentsOf: Array(repeating: "", count: 6 - updatedPhotoURLs.count))
                }

                for (index, image) in selectedImages.enumerated() {
                    guard let image else { continue }

                    let url = try await profileService.uploadPhoto(
                        image: image,
                        uid: uid,
                        index: index
                    )

                    if updatedPhotoURLs.indices.contains(index) {
                        updatedPhotoURLs[index] = url
                    } else {
                        updatedPhotoURLs.append(url)
                    }
                }

                try await profileService.savePhotos(photoURLs: updatedPhotoURLs, uid: uid)
            }

            saveSucceeded = true
            selectedImages = Array(repeating: nil, count: 6)
            await loadProfile()

        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    // MARK: - Spotify

    func refreshSpotifyProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "No Firebase user."
            return
        }

        isRefreshingSpotify = true
        errorMessage = nil

        do {
            try await profileService.refreshSpotifyProfile(uid: uid)
            await loadProfile()
        } catch {
            errorMessage = error.localizedDescription
        }

        isRefreshingSpotify = false
    }

    // MARK: - Helpers

    private func applyProfile(_ profile: UserProfile) {
        self.profile = profile
        firstName = profile.firstName
        lastName = profile.lastName
        city = profile.city
        birthday = profile.birthday ?? Date()
        gender = profile.gender
        photoURLs = profile.photoURLs

        // ✅ Snapshot für soft discard
        snapshot = Snapshot(
            firstName: firstName,
            lastName: lastName,
            city: city,
            birthday: birthday,
            gender: gender,
            photoURLs: photoURLs,
            profile: profile
        )

        selectedImages = Array(repeating: nil, count: 6)
    }
}

