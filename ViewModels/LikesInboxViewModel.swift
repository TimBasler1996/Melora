//
//  LikesInboxViewModel.swift
//  SocialSound
//
//  Created by Tim Basler on 21.11.2025.
//


import Foundation

@MainActor
final class LikesInboxViewModel: ObservableObject {
    
    @Published var clusters: [TrackLikesCluster] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    /// Wann der User die Inbox das letzte Mal gesehen hat.
    @Published var lastSeenDate: Date?
    
    private let likeService = LikeApiService.shared
    private let lastSeenKey = "LikesInboxView_lastSeenDate"
    
    init() {
        loadLastSeenDate()
    }
    
    // MARK: - Public API
    
    func loadLikes(for userId: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                var likes = try await likeService.fetchLikesReceived(for: userId)
                
                // ✅ IMPORTANT: Enrich likes with missing user data
                print("🔄 [Inbox] Fetched \(likes.count) likes, enriching with user data...")
                
                // Debug: Check what data we have before enrichment
                for (index, like) in likes.enumerated().prefix(3) {
                    print("  📋 Like \(index): fromUserId=\(like.fromUserId), displayName=\(like.fromUserDisplayName ?? "nil"), avatar=\(like.fromUserAvatarURL ?? "nil")")
                }
                
                likes = await likeService.enrichLikesWithUserData(likes)
                
                // Debug: Check what data we have after enrichment
                print("✅ [Inbox] Likes enriched, checking results...")
                for (index, like) in likes.enumerated().prefix(3) {
                    print("  ✨ Like \(index): fromUserId=\(like.fromUserId), displayName=\(like.fromUserDisplayName ?? "nil"), avatar=\(like.fromUserAvatarURL ?? "nil")")
                }
                
                let newClusters = buildClusters(from: likes)
                
                self.clusters = newClusters
                self.isLoading = false
            } catch {
                print("❌ Failed to load likes: \(error)")
                self.errorMessage = "Could not load your likes. Please try again later."
                self.isLoading = false
            }
        }
    }
    
    /// Wird in `LikesInboxView.onDisappear` aufgerufen.
    func markAllAsSeen() {
        let now = Date()
        lastSeenDate = now
        saveLastSeenDate(now)
    }
    
    // MARK: - Private helpers
    
    private func buildClusters(from likes: [TrackLike]) -> [TrackLikesCluster] {
        // Gruppiere nach trackId
        let grouped = Dictionary(grouping: likes, by: { $0.trackId })
        
        let clusters: [TrackLikesCluster] = grouped.compactMap { (_, likesForTrack) in
            guard let first = likesForTrack.first else { return nil }
            
            let lastLikeAt = likesForTrack.map(\.createdAt).max() ?? first.createdAt
            
            return TrackLikesCluster(
                id: first.trackId,
                trackTitle: first.trackTitle,
                trackArtist: first.trackArtist,
                trackAlbum: first.trackAlbum,
                likeCount: likesForTrack.count,
                lastLikeAt: lastLikeAt,
                likes: likesForTrack,
                trackArtworkURL: first.trackArtworkURL   // 👈 Cover aus dem ersten Like
            )
        }
        
        // Sortiert nach Zeit (neueste oben)
        return clusters.sorted(by: { $0.lastLikeAt > $1.lastLikeAt })
    }
    
    private func loadLastSeenDate() {
        if let stored = UserDefaults.standard.object(forKey: lastSeenKey) as? Date {
            lastSeenDate = stored
        } else {
            lastSeenDate = nil
        }
    }
    
    private func saveLastSeenDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastSeenKey)
    }
}
