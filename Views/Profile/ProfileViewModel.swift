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

    @Published var photoURLs: [String] = []
    @Published var selectedImages: [UIImage?] = [nil, nil, nil]

    // MARK: - Spotify

    @Published var isRefreshingSpotify: Bool = false

    // MARK: - Services

    private let profileService: ProfileService

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

    /// ✅ App / Runtime Init
    init() {
        self.profileService = ProfileService()
    }

    /// ✅ Preview / Test Init (NO Firebase, NO async)
    init(preview: Bool) {
        self.profileService = ProfileService()

        guard preview else { return }

        let mock = UserProfile.mockPreview
        self.profile = mock
        self.firstName = mock.firstName
        self.lastName = mock.lastName
        self.city = mock.city
        self.birthday = mock.birthday ?? Date()
        self.gender = mock.gender
        self.photoURLs = mock.photoURLs
        self.selectedImages = [nil, nil, nil]
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

            if selectedImages.contains(where: { $0 != nil }) {
                var updatedPhotoURLs = photoURLs

                if updatedPhotoURLs.count < 3 {
                    updatedPhotoURLs.append(
                        contentsOf: Array(repeating: "", count: 3 - updatedPhotoURLs.count)
                    )
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

                try await profileService.savePhotos(
                    photoURLs: updatedPhotoURLs,
                    uid: uid
                )
            }

            saveSucceeded = true
            selectedImages = [nil, nil, nil]
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
        self.firstName = profile.firstName
        self.lastName = profile.lastName
        self.city = profile.city
        self.birthday = profile.birthday ?? Date()
        self.gender = profile.gender
        self.photoURLs = profile.photoURLs
        self.selectedImages = [nil, nil, nil]
    }
}

