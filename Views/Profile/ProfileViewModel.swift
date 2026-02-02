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
    @Published var draft: ProfileDraft?

    // MARK: - Spotify

    @Published var isRefreshingSpotify: Bool = false

    // MARK: - Services

    private let profileService: ProfileService

    // MARK: - Draft snapshot (for change detection)

    private var draftSnapshot: Snapshot?

    struct ProfileDraft {
        var firstName: String
        var lastName: String
        var city: String
        var birthday: Date
        var gender: String
        var photoURLs: [String]
        var selectedImages: [UIImage?]
        var heroImageChanged: Bool // Track if hero image was changed
    }

    private struct Snapshot {
        let firstName: String
        let lastName: String
        let city: String
        let birthday: Date
        let gender: String
        let photoURLs: [String]
    }

    // MARK: - Computed

    var hasDraftChanges: Bool {
        guard let draft, let snapshot = draftSnapshot else { return false }

        let basicsChanged =
            draft.firstName != snapshot.firstName ||
            draft.lastName != snapshot.lastName ||
            draft.city != snapshot.city ||
            draft.gender != snapshot.gender ||
            draft.birthday != snapshot.birthday

        let photosChanged = (draft.photoURLs != snapshot.photoURLs) || draft.selectedImages.contains { $0 != nil }
        return basicsChanged || photosChanged
    }

    // MARK: - Initializers

    init() {
        self.profileService = ProfileService()
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

    // MARK: - Draft management

    func beginEditing() {
        guard draft == nil else { return }

        let snapshot = snapshotFromProfile(profile)
        draftSnapshot = snapshot

        draft = ProfileDraft(
            firstName: snapshot.firstName,
            lastName: snapshot.lastName,
            city: snapshot.city,
            birthday: snapshot.birthday,
            gender: snapshot.gender,
            photoURLs: snapshot.photoURLs,
            selectedImages: Array(repeating: nil, count: 6),
            heroImageChanged: false
        )
    }

    func updateDraft(_ update: (inout ProfileDraft) -> Void) {
        guard var draft else { return }
        update(&draft)
        self.draft = draft
    }

    func setDraftSelectedImage(_ image: UIImage?, index: Int) {
        updateDraft { draft in
            guard draft.selectedImages.indices.contains(index) else { return }
            draft.selectedImages[index] = image
            
            // Mark hero image as changed if it's the first photo (index 0)
            if index == 0 && image != nil {
                draft.heroImageChanged = true
            }
        }
    }

    /// Entfernt ein Foto aus dem Slot (soft delete) und markiert es für Save.
    func removeDraftPhoto(at index: Int) {
        updateDraft { draft in
            guard draft.photoURLs.indices.contains(index) else { return }
            draft.photoURLs[index] = ""
            draft.selectedImages[index] = nil
        }
    }

    func discardDraft() {
        draft = nil
        draftSnapshot = nil
        saveSucceeded = false
        errorMessage = nil
    }

    // MARK: - Saving

    @discardableResult
    func saveDraftChanges() async -> Bool {
        guard let currentDraft = draft else { return false }
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "No Firebase user."
            return false
        }

        isSaving = true
        saveSucceeded = false
        errorMessage = nil

        do {
            let basics = OnboardingProfileService.Basics(
                firstName: currentDraft.firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: currentDraft.lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                city: currentDraft.city.trimmingCharacters(in: .whitespacesAndNewlines),
                birthday: currentDraft.birthday,
                gender: currentDraft.gender.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            try await profileService.saveBasics(basics, uid: uid)

            // Fotos: wir arbeiten mit 6 Slots ("" = gelöscht)
            let photosNeedSave = (draftSnapshot?.photoURLs != currentDraft.photoURLs) || currentDraft.selectedImages.contains(where: { $0 != nil })
            if photosNeedSave {
                var updatedPhotoURLs = currentDraft.photoURLs

                // Handle hero photo (index 0) - save uncropped version separately
                if let heroImage = currentDraft.selectedImages[0], currentDraft.heroImageChanged {
                    // Upload uncropped hero photo
                    let heroURL = try await profileService.uploadHeroPhoto(image: heroImage, uid: uid)
                    try await profileService.saveHeroPhotoURL(heroURL, uid: uid)
                    
                    // Also crop and upload for discovery cards (index 0 in photoURLs)
                    // Note: In a real implementation, you'd want to crop this image
                    // For now, we'll use the same image, but ideally crop it to square
                    let croppedURL = try await profileService.uploadPhoto(
                        image: heroImage,
                        uid: uid,
                        index: 0
                    )
                    if updatedPhotoURLs.indices.contains(0) {
                        updatedPhotoURLs[0] = croppedURL
                    } else {
                        updatedPhotoURLs.insert(croppedURL, at: 0)
                    }
                }

                // Handle other photos (indices 1-5)
                for (index, image) in currentDraft.selectedImages.enumerated() {
                    guard index > 0 else { continue } // Skip index 0, handled above
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
            draft = nil
            draftSnapshot = nil
            await loadProfile()
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
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
    }

    private func snapshotFromProfile(_ profile: UserProfile?) -> Snapshot {
        let fallbackDate = Date()
        let photoURLs = paddedPhotoURLs(profile?.photoURLs ?? [])

        return Snapshot(
            firstName: profile?.firstName ?? "",
            lastName: profile?.lastName ?? "",
            city: profile?.city ?? "",
            birthday: profile?.birthday ?? fallbackDate,
            gender: profile?.gender ?? "",
            photoURLs: photoURLs
        )
    }

    private func paddedPhotoURLs(_ urls: [String]) -> [String] {
        var padded = urls
        if padded.count < 6 {
            padded.append(contentsOf: Array(repeating: "", count: 6 - padded.count))
        } else if padded.count > 6 {
            padded = Array(padded.prefix(6))
        }
        return padded
    }
}
