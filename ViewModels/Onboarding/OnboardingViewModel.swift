import Foundation
import AuthenticationServices
import FirebaseAuth
import UIKit

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Step navigation

    @Published var stepIndex: Int = 1

    /// The welcome screen shown before step 1 (what the app is, in one screen).
    @Published var hasSeenWelcome: Bool = false

    static let stepCount = 4
    var progressText: String { "\(stepIndex)/\(Self.stepCount)" }
    var progressValue: Double { Double(stepIndex) / Double(Self.stepCount) }

    // MARK: - Step 1: Basics

    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var city: String = ""
    @Published var birthday: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @Published var gender: String = ""
    @Published var lookingFor: String = ""

    // MARK: - Step 2: Photos (2-5 required)

    @Published var selectedImages: [UIImage?] = [nil, nil, nil, nil, nil] // Max 5 photos
    @Published var uploadedPhotoURLs: [String] = []
    /// The exact images `uploadedPhotoURLs` were made from, so a retry after
    /// a later failure doesn't upload them again.
    private var uploadedImages: [UIImage] = []

    // MARK: - Step 3: Spotify

    @Published var spotifyConnected: Bool = false
    @Published var spotifyErrorMessage: String?

    /// True when the user chose "Skip for now" on the Spotify step. They can
    /// connect later from the Now Playing tab or profile settings.
    @Published var spotifySkipped: Bool = false

    // MARK: - Finish

    @Published var isConnectingSpotify: Bool = false
    @Published var isFinishing: Bool = false
    @Published var finishErrorMessage: String?
    /// What the finish step is doing right now ("Uploading photo 2 of 4…").
    @Published var finishProgressText: String?
    @Published var didFinish: Bool = false

    // MARK: - Step 4: Keep your profile (Sign in with Apple, optional)

    @Published var isLinkingAccount: Bool = false
    @Published var accountErrorMessage: String?

    /// Lazy so SwiftUI previews can construct the view model without a
    /// configured Firebase app (the service touches Firestore/Storage on init).
    private lazy var profileService = OnboardingProfileService()

    // MARK: - Validation

    var canContinueStep1: Bool {
        let f = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let g = gender.trimmingCharacters(in: .whitespacesAndNewlines)

        guard f.count >= 2, l.count >= 2, c.count >= 2, !g.isEmpty else { return false }

        let today = Calendar.current.startOfDay(for: Date())
        let sel = Calendar.current.startOfDay(for: birthday)
        guard sel <= today else { return false }
        guard birthday >= minimumBirthday else { return false }

        return true
    }

    var canContinueStep2: Bool {
        let nonNilImages = selectedImages.compactMap { $0 }
        return nonNilImages.count >= 2 // Minimum 2 photos required
    }
    
    var selectedImagesCount: Int {
        selectedImages.compactMap { $0 }.count
    }

    /// ✅ Used by the FlowView (no bindings, pure Bool)
    var canContinueCurrentStep: Bool {
        switch stepIndex {
        case 1: return canContinueStep1
        case 2: return canContinueStep2
        case 3: return spotifyConnected
        default: return false
        }
    }

    var canFinish: Bool {
        (spotifyConnected || spotifySkipped) && !isFinishing
    }

    private var minimumBirthday: Date {
        Calendar.current.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? Date.distantPast
    }

    // MARK: - Nav

    func goNext() {
        switch stepIndex {
        case 1:
            guard canContinueStep1 else { return }
            stepIndex = 2
        case 2:
            guard canContinueStep2 else { return }
            stepIndex = 3
        default:
            break
        }
    }

    func goBack() {
        // Step 4 comes after the profile was written; there is nothing to go back to.
        guard stepIndex > 1, stepIndex < 4 else { return }
        stepIndex -= 1
    }

    // MARK: - Step 4: account

    func skipAccountStep() {
        didFinish = true
    }

    func completeAppleSignIn(
        _ result: Result<ASAuthorization, Error>,
        using account: AccountService,
        stopping broadcast: BroadcastManager
    ) async {
        accountErrorMessage = nil
        isLinkingAccount = true
        defer { isLinkingAccount = false }

        do {
            _ = try await account.completeAppleSignIn(result, stopping: broadcast)
            didFinish = true
        } catch AccountService.AccountError.cancelled {
            // User backed out of the Apple sheet; stay on the step.
        } catch {
            print("❌ [Account] Apple link failed: \(error)")
            accountErrorMessage = "Couldn’t link your Apple ID. You can try again later in Settings."
        }
    }

    // MARK: - Step 3: Spotify connect

    func connectSpotify(using spotifyAuth: SpotifyAuthManager) async {
        spotifyErrorMessage = nil
        isConnectingSpotify = true
        defer { isConnectingSpotify = false }

        spotifyAuth.ensureAuthorized()

        do {
            _ = try await waitUntilSpotifyAuthorized(spotifyAuth: spotifyAuth, timeoutSeconds: 90)

            let profile = try await SpotifyService.shared.fetchCurrentUserProfile()

            let spotifyId = profile.id
            guard !spotifyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                spotifyErrorMessage = "Spotify didn’t return your account. Please try again."
                return
            }

            guard let uid = Auth.auth().currentUser?.uid else {
                spotifyErrorMessage = "You’re not signed in yet. Try again in a moment."
                return
            }

            let avatarString: String? = profile.imageURL?.absoluteString

            try await profileService.saveSpotify(
                spotifyId: spotifyId,
                countryCode: profile.country,
                spotifyAvatarURL: avatarString,
                uid: uid
            )

            spotifyConnected = true
        } catch SpotifyLoginError.cancelled {
            // The user closed the Spotify sheet; nothing to explain.
            spotifyErrorMessage = nil
        } catch SpotifyLoginError.failed {
            spotifyErrorMessage = "Spotify didn’t connect. Check your connection and try again."
        } catch {
            spotifyErrorMessage = UserFacingError.message(
                for: error,
                fallback: "Spotify didn’t connect. Please try again."
            )
        }
    }

    private enum SpotifyLoginError: Error {
        case cancelled
        case failed
    }

    private func waitUntilSpotifyAuthorized(spotifyAuth: SpotifyAuthManager, timeoutSeconds: TimeInterval) async throws -> String {
        let start = Date()

        while spotifyAuth.isAuthorized == false {
            // The login sheet was closed or failed: stop waiting right away.
            switch spotifyAuth.lastLoginFailure {
            case .cancelled: throw SpotifyLoginError.cancelled
            case .failed: throw SpotifyLoginError.failed
            case nil: break
            }
            if Date().timeIntervalSince(start) > timeoutSeconds {
                throw SpotifyLoginError.failed
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }

        return try await spotifyAuth.getValidAccessToken()
    }

    // MARK: - Finish

    func finish(using spotifyAuth: SpotifyAuthManager) async {
        finishErrorMessage = nil
        guard canContinueStep1 else { finishErrorMessage = "Please complete your profile details."; return }
        guard canContinueStep2 else { finishErrorMessage = "Please add at least 2 photos."; return }
        guard spotifyConnected || spotifySkipped else {
            finishErrorMessage = "Connect Spotify or choose “Skip for now”."
            return
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            finishErrorMessage = "You’re not signed in yet. Try again in a moment."
            return
        }

        isFinishing = true
        defer {
            isFinishing = false
            finishProgressText = nil
        }

        do {
            finishProgressText = "Saving your profile…"
            let trimmedLookingFor = lookingFor.trimmingCharacters(in: .whitespacesAndNewlines)
            let basics = OnboardingProfileService.Basics(
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                birthday: birthday,
                gender: gender.trimmingCharacters(in: .whitespacesAndNewlines),
                lookingFor: trimmedLookingFor.isEmpty ? nil : trimmedLookingFor
            )
            try await profileService.saveBasics(basics, uid: uid)

            let images = selectedImages.compactMap { $0 }
            let urls = try await uploadPhotosIfNeeded(images, uid: uid)
            finishProgressText = "Almost done…"
            try await profileService.savePhotos(photoURLs: urls, uid: uid)

            if spotifyConnected {
                _ = try await spotifyAuth.getValidAccessToken()
            }

            try await profileService.markCompleted(uid: uid)

            // Profile is complete. One more (skippable) step: keep it safe.
            stepIndex = 4
        } catch {
            finishErrorMessage = UserFacingError.message(
                for: error,
                fallback: "Couldn’t finish your profile. Please try again."
            )
        }
    }

    /// Uploads the photos one by one with progress, reusing the URLs from a
    /// previous attempt when the same images are still selected.
    private func uploadPhotosIfNeeded(_ images: [UIImage], uid: String) async throws -> [String] {
        let unchanged = images.count == uploadedImages.count
            && zip(images, uploadedImages).allSatisfy { $0 === $1 }
        if unchanged, uploadedPhotoURLs.count == images.count {
            return uploadedPhotoURLs
        }

        var urls: [String] = []
        var done: [UIImage] = []
        for (index, image) in images.enumerated() {
            finishProgressText = "Uploading photo \(index + 1) of \(images.count)…"
            // Reuse a photo already uploaded at the same slot last time.
            if index < uploadedImages.count, uploadedImages[index] === image, index < uploadedPhotoURLs.count {
                urls.append(uploadedPhotoURLs[index])
            } else {
                urls.append(try await profileService.uploadPhoto(image: image, uid: uid, index: index))
            }
            done.append(image)
            // Remember partial progress so a failure on photo 3 keeps 1 and 2.
            uploadedImages = done
            uploadedPhotoURLs = urls
        }
        return urls
    }
}

