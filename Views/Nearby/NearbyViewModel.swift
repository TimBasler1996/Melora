import Foundation

/// View model for the "Nearby" screen.
/// Loads active broadcasts from DiscoverService.
@MainActor
final class NearbyViewModel: ObservableObject {
    
    @Published var broadcasts: [DiscoverBroadcast] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let discoverService = DiscoverService.shared
    
    /// Triggers loading nearby broadcasts with an optional location.
    func loadNearbyBroadcasts(location: LocationPoint?) {
        Task {
            await load(location: location)
        }
    }
    
    private func load(location: LocationPoint?) async {
        isLoading = true
        errorMessage = nil
        
        let loc = location ?? LocationPoint(latitude: 47.0, longitude: 8.0)
        
        do {
            let result = try await discoverService.fetchNearbyBroadcasts(
                around: loc,
                radiusMeters: 5000
            )
            self.broadcasts = result
        } catch {
            print("❌ Failed to load nearby broadcasts: \(error)")
            self.errorMessage = "Failed to load nearby broadcasts."
        }
        
        isLoading = false
    }
}
