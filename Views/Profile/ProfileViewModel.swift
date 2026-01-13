import Foundation
import FirebaseAuth
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var saveSucceeded: Bool = false
    @Published var errorMessage: String?

    @Published var profile: UserProfile?

    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var city: String = ""
    @Published var birthday: Date = Date()
    @Published var gender: String = ""

    @Published var photoURLs: [String] = []
    @Published var selectedImages: [UIImage?] = [nil, nil, nil]

    @Published var isRefreshingSpotify: Bool = false

    private let profileService = ProfileService()

    var ageText: String {
        birthday.age().map(String.init) ?? ""
    }

    var hasChanges: Bool {
        guard let profile else { return false }
        let basicsChanged =
            firstName != profile.firstName
            || lastName != profile.lastName
            || city != profile.city
            || gender != profile.gender
            || birthday != (profile.birthday ?? birthday)

        let photosChanged = selectedImages.contains { $0 != nil }
        return basicsChanged || photosChanged
    }

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

    func setSelectedImage(_ image: UIImage?, index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages[index] = image
    }

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
                    updatedPhotoURLs.append(contentsOf: Array(repeating: "", count: 3 - updatedPhotoURLs.count))
                }

                for (index, image) in selectedImages.enumerated() {
                    guard let image else { continue }
                    let url = try await profileService.uploadPhoto(image: image, uid: uid, index: index)
                    if updatedPhotoURLs.indices.contains(index) {
                        updatedPhotoURLs[index] = url
                    } else {
                        updatedPhotoURLs.append(url)
                    }
                }

                try await profileService.savePhotos(photoURLs: updatedPhotoURLs, uid: uid)
            }

            saveSucceeded = true
            selectedImages = [nil, nil, nil]
            await loadProfile()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

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

    private func applyProfile(_ profile: UserProfile) {
        self.profile = profile
        firstName = profile.firstName
        lastName = profile.lastName
        city = profile.city
        birthday = profile.birthday ?? Date()
        gender = profile.gender
        photoURLs = profile.photoURLs
        selectedImages = [nil, nil, nil]
    }
}
