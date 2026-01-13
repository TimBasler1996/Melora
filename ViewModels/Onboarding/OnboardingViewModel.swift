import Foundation
import FirebaseAuth
import UIKit

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Step navigation

    @Published var stepIndex: Int = 1

    var progressText: String { "\(stepIndex)/3" }
    var progressValue: Double { Double(stepIndex) / 3.0 }

    // MARK: - Step 1: Basics

    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var city: String = ""
    @Published var birthday: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @Published var gender: String = ""

    // MARK: - Step 2: Photos (3 required)

    @Published var selectedImages: [UIImage?] = [nil, nil, nil]
    @Published var uploadedPhotoURLs: [String] = []

    // MARK: - Step 3: Spotify

    @Published var spotifyConnected: Bool = false
    @Published var spotifyErrorMessage: String?

    // MARK: - Finish

    @Published var isConnectingSpotify: Bool = false
    @Published var isFinishing: Bool = false
    @Published var finishErrorMessage: String?
    @Published var didFinish: Bool = false

    private let profileService = OnboardingProfileService()

    // MARK: - Validation

    var canContinueStep1: Bool {
        let f = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let g = gender.trimmingCharacters(in: .whitespacesAndNewlines)

        guard f.count >= 2, l.count >= 2, c.count >= 2, !g.isEmpty else { return false }

        // Birthday must be <= today and not absurdly old
        let today = Calendar.current.startOfDay(for: Date())
        let sel = Calendar.current.startOfDay(for: birthday)
        guard sel <= today else { return false }
        guard birthday >= minimumBirthday else { return false }

        return true
    }

    var canContinueStep2: Bool {
        selectedImages.allSatisfy { $0 != nil }
    }

    var canFinish: Bool {
        spotifyConnected && !isFinishing
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
        guard stepIndex > 1 else { return }
        stepIndex -= 1
    }

    // MARK: - Step 3: Spotify connect

    func connectSpotify(using spotifyAuth: SpotifyAuthManager) async {
        spotifyErrorMessage = nil
        isConnectingSpotify = true
        defer { isConnectingSpotify = false }

        // Trigger auth flow (opens browser)
        spotifyAuth.ensureAuthorized()

        do {
            // Wait until access token is valid (this will refresh if needed)
            _ = try await waitUntilSpotifyAuthorized(spotifyAuth: spotifyAuth, timeoutSeconds: 90)

            // Fetch /v1/me
            let profile = try await SpotifyService.shared.fetchCurrentUserProfile()
            guard let spotifyId = profile.id, !spotifyId.isEmpty else {
                spotifyErrorMessage = "Could not read Spotify user id."
                return
            }

            // Store spotify fields immediately
            guard let uid = Auth.auth().currentUser?.uid else {
                spotifyErrorMessage = "Not authenticated."
                return
            }

            try await profileService.saveSpotify(
                spotifyId: spotifyId,
                countryCode: profile.country,
                spotifyAvatarURL: profile.imageURL,
                uid: uid
            )

            spotifyConnected = true
        } catch {
            spotifyErrorMessage = "Spotify connection failed. Please try again."
        }
    }

    private func waitUntilSpotifyAuthorized(spotifyAuth: SpotifyAuthManager, timeoutSeconds: TimeInterval) async throws -> String {
        let start = Date()

        while spotifyAuth.isAuthorized == false {
            if Date().timeIntervalSince(start) > timeoutSeconds {
                throw SpotifyAuthError.notAuthorized
            }
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        }

        return try await spotifyAuth.getValidAccessToken()
    }

    // MARK: - Finish (uploads + writes profile + marks completed)

    func finish(using spotifyAuth: SpotifyAuthManager) async {
        finishErrorMessage = nil
        guard canContinueStep1 else { finishErrorMessage = "Please complete your profile details."; return }
        guard canContinueStep2 else { finishErrorMessage = "Please add all 3 photos."; return }
        guard spotifyConnected else { finishErrorMessage = "Spotify is required."; return }

        guard let uid = Auth.auth().currentUser?.uid else {
            finishErrorMessage = "Not authenticated."
            return
        }

        isFinishing = true
        defer { isFinishing = false }

        do {
            // 1) Save basics
            let basics = OnboardingProfileService.Basics(
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                birthday: birthday,
                gender: gender.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            try await profileService.saveBasics(basics, uid: uid)

            // 2) Upload photos
            let images = selectedImages.compactMap { $0 }
            let urls = try await profileService.uploadPhotos(images: images, uid: uid)
            uploadedPhotoURLs = urls
            try await profileService.savePhotos(photoURLs: urls, uid: uid)

            // 3) Ensure Spotify token still valid (mandatory)
            _ = try await spotifyAuth.getValidAccessToken()

            // 4) Mark completed
            try await profileService.markCompleted(uid: uid)

            didFinish = true
        } catch {
            finishErrorMessage = error.localizedDescription
        }
    }
}

