import Foundation

@MainActor
final class NowPlayingViewModel: ObservableObject {

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentTrack: Track?

    func fetchCurrentTrack() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                let track = try await SpotifyService.shared.fetchCurrentlyPlaying()
                self.currentTrack = track
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = "Could not load current track."
            }
        }
    }
}

