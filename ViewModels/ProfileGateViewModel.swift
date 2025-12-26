//
//  ProfileGateViewModel.swift
//  SocialSound
//

import Foundation

@MainActor
final class ProfileGateViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var appUser: AppUser?
    @Published var needsOnboarding: Bool = false

    private let userService: UserApiService

    init(userService: UserApiService = .shared) {
        self.userService = userService
    }

    func bootstrap() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                // 1) Spotify /me
                let spotifyProfile = try await SpotifyService.shared.fetchCurrentUserProfile()

                // Werte VOR der Closure rausziehen (sonst "spotify not in scope" / Capture-Probleme)
                let spotifyId = spotifyProfile.id
                let displayName = spotifyProfile.displayName
                let countryCode = spotifyProfile.countryCode
                let avatarURL = spotifyProfile.imageURL?.absoluteString

                // 2) Ensure Firestore user exists (uid doc) + return AppUser
                userService.ensureCurrentUserExistsFromSpotify(
                    spotifyId: spotifyId,
                    displayName: displayName,
                    countryCode: countryCode,
                    avatarURL: avatarURL
                ) { [weak self] result in
                    guard let self else { return }

                    self.isLoading = false
                    switch result {
                    case .failure(let error):
                        self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                        self.appUser = nil
                        self.needsOnboarding = false

                    case .success(let user):
                        self.errorMessage = nil
                        self.appUser = user
                        let completed = user.profileCompleted ?? user.isCompleteDerived
                        self.needsOnboarding = !completed
                    }
                }

            } catch {
                isLoading = false
                errorMessage = "Spotify profile fetch failed."
            }
        }
    }
}
