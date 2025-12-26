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
                let spotify = try await SpotifyService.shared.fetchCurrentUserProfile()

                let ensuredUser = try await ensureUserFromSpotifyAsync(
                    spotifyId: spotify.id,
                    displayName: spotify.displayName,
                    avatarURL: spotify.imageURL?.absoluteString,   // ✅ avatarURL BEFORE countryCode
                    countryCode: spotify.countryCode
                )

                self.appUser = ensuredUser
                let completed = ensuredUser.profileCompleted ?? ensuredUser.isCompleteDerived
                self.needsOnboarding = !completed
                self.isLoading = false

            } catch {
                self.isLoading = false
                self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
            }
        }
    }

    private func ensureUserFromSpotifyAsync(
        spotifyId: String,
        displayName: String,
        avatarURL: String?,
        countryCode: String?
    ) async throws -> AppUser {
        try await withCheckedThrowingContinuation { continuation in
            userService.ensureCurrentUserExistsFromSpotify(
                spotifyId: spotifyId,
                displayName: displayName,
                avatarURL: avatarURL,
                countryCode: countryCode
            ) { result in
                continuation.resume(with: result)
            }
        }
    }
}

