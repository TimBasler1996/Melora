import Foundation

/// View model for the "Nearby" screen.
/// Loads active sessions from SessionApiService.
@MainActor
final class NearbyViewModel: ObservableObject {
    
    @Published var sessions: [Session] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let sessionService = SessionApiService.shared
    
    /// Triggers loading nearby sessions with an optional location.
    func loadNearbySessions(location: LocationPoint?) {
        Task {
            await load(location: location)
        }
    }
    
    private func load(location: LocationPoint?) async {
        isLoading = true
        errorMessage = nil
        
        let loc = location ?? LocationPoint(latitude: 47.0, longitude: 8.0)
        
        do {
            let result = try await sessionService.fetchNearbySessions(around: loc)
            self.sessions = result
        } catch {
            print("❌ Failed to load nearby sessions: \(error)")
            self.errorMessage = "Failed to load nearby sessions."
        }
        
        isLoading = false
    }
}
