import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

@MainActor
final class DiscoverViewModel: ObservableObject {

    @Published private(set) var visibleBroadcasts: [DiscoverBroadcast] = []
    @Published var isLoading: Bool = false
    @Published var isSendingLike: Bool = false
    @Published var errorMessage: String?

    @Published var selectedBroadcast: DiscoverBroadcast?
    @Published var dismissTarget: DiscoverBroadcast?
    
    // Track broadcasts that have been liked and messaged
    @Published private(set) var likedBroadcastIds: Set<String> = []
    @Published private(set) var messagedBroadcastIds: Set<String> = []

    private let service: DiscoverService
    private let likeService: LikeApiService
    private let chatService: ChatApiService

    private var listener: ListenerRegistration?
    private var pollTimer: Task<Void, Never>?
    private var allBroadcasts: [DiscoverBroadcast] = []
    private var cachedUsers: [String: DiscoverUser] = [:]

    private var mutedUserIds: Set<String> = []
    private var mutedTrackIds: Set<String> = []
    private var currentLocation: CLLocation?

    private var isListening = false

    init(
        service: DiscoverService = .shared,
        likeService: LikeApiService = .shared,
        chatService: ChatApiService = .shared
    ) {
        self.service = service
        self.likeService = likeService
        self.chatService = chatService
        loadLikedBroadcastsFromCache()
        loadMessagedBroadcastsFromCache()
    }

    deinit {
        Task { @MainActor in
            stopListening()
            pollTimer?.cancel()
        }
    }

    func startListening() {
        guard !isListening else { return }
        guard !isRunningInPreview else { return }
        isListening = true
        isLoading = true
        errorMessage = nil

        loadMutedPreferencesIfNeeded()

        listener = service.listenToBroadcasts { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.allBroadcasts = []
                    self.visibleBroadcasts = []
                case .success(let records):
                    await self.handleBroadcastRecords(records)
                }
            }
        }
        
        // Start polling timer for refresh every 5 seconds
        startPolling()
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        pollTimer?.cancel()
        pollTimer = nil
        isListening = false
    }
    
    private func startPolling() {
        pollTimer?.cancel()
        pollTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                guard !Task.isCancelled else { break }
                await self?.refreshBroadcasts()
            }
        }
    }
    
    private func refreshBroadcasts() async {
        // Silently refresh without showing loading indicator
        // The listener will automatically get updates, this is just a safety mechanism
    }

    func updateCurrentLocation(_ location: LocationPoint?) {
        if let location {
            currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        } else {
            currentLocation = nil
        }
        updateVisibleBroadcasts()
    }

    func requestDismiss(for broadcast: DiscoverBroadcast) {
        dismissTarget = broadcast
    }

    func cancelDismiss() {
        dismissTarget = nil
    }

    func muteUser(for broadcast: DiscoverBroadcast) {
        mutedUserIds.insert(broadcast.user.id)
        persistMutedPreferences()
        removeBroadcast(broadcast)
    }

    func muteTrack(for broadcast: DiscoverBroadcast) {
        mutedTrackIds.insert(broadcast.track.id)
        persistMutedPreferences()
        removeBroadcast(broadcast)
    }

    func sendLike(
        for broadcast: DiscoverBroadcast,
        from currentUser: AppUser?,
        message: String?
    ) async throws {
        isSendingLike = true
        defer { isSendingLike = false }
        guard let senderId = service.currentUserId() else {
            throw NSError(domain: "Discover", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let receiverUser = AppUser(
            uid: broadcast.user.id,
            displayName: broadcast.user.displayName,
            avatarURL: broadcast.user.profilePhotoURL,
            photoURLs: broadcast.user.photoURLs
        )

        let track = Track(
            id: broadcast.track.id,
            title: broadcast.track.title,
            artist: broadcast.track.artist,
            album: broadcast.track.album,
            artworkURL: broadcast.track.artworkURLValue
        )

        let like = try await likeService.likeBroadcastTrack(
            fromUser: currentUser,
            toUser: receiverUser,
            track: track,
            sessionLocation: nil,
            placeLabel: nil,
            message: message
        )

        try await service.writeLikeEvent(
            senderId: senderId,
            receiverId: broadcast.user.id,
            track: broadcast.track,
            message: message,
            broadcastId: broadcast.id
        )

        let trimmedMessage = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMessage.isEmpty {
            try await chatService.sendMessage(
                from: senderId,
                to: broadcast.user.id,
                text: trimmedMessage,
                createdFromTrackId: broadcast.track.id,
                createdFromLikeId: like.id
            )
            // Mark this broadcast as messaged
            messagedBroadcastIds.insert(broadcast.id)
            saveMessagedBroadcastsToCache()
        }
        
        // Mark this broadcast as liked
        likedBroadcastIds.insert(broadcast.id)
        saveLikedBroadcastsToCache()
    }
    
    func isLiked(_ broadcast: DiscoverBroadcast) -> Bool {
        likedBroadcastIds.contains(broadcast.id)
    }
    
    func hasMessage(_ broadcast: DiscoverBroadcast) -> Bool {
        messagedBroadcastIds.contains(broadcast.id)
    }
    
    // MARK: - Cache Management
    
    private func loadLikedBroadcastsFromCache() {
        guard let uid = service.currentUserId() else { return }
        let defaults = UserDefaults.standard
        let key = "discover.likedBroadcasts.\(uid)"
        let cached = defaults.stringArray(forKey: key) ?? []
        likedBroadcastIds = Set(cached)
    }
    
    private func saveLikedBroadcastsToCache() {
        guard let uid = service.currentUserId() else { return }
        let defaults = UserDefaults.standard
        let key = "discover.likedBroadcasts.\(uid)"
        defaults.set(Array(likedBroadcastIds), forKey: key)
    }
    
    private func loadMessagedBroadcastsFromCache() {
        guard let uid = service.currentUserId() else { return }
        let defaults = UserDefaults.standard
        let key = "discover.messagedBroadcasts.\(uid)"
        let cached = defaults.stringArray(forKey: key) ?? []
        messagedBroadcastIds = Set(cached)
    }
    
    private func saveMessagedBroadcastsToCache() {
        guard let uid = service.currentUserId() else { return }
        let defaults = UserDefaults.standard
        let key = "discover.messagedBroadcasts.\(uid)"
        defaults.set(Array(messagedBroadcastIds), forKey: key)
    }

    func selectBroadcast(_ broadcast: DiscoverBroadcast) {
        selectedBroadcast = broadcast
    }

    private func handleBroadcastRecords(_ records: [DiscoverService.BroadcastRecord]) async {
        let currentUserId = service.currentUserId()
        let filtered = records.filter { record in
            if let currentUserId, record.userId == currentUserId { return false }
            if mutedUserIds.contains(record.userId) { return false }
            if mutedTrackIds.contains(record.trackId) { return false }
            return true
        }

        let userIds = Set(filtered.map { $0.userId })
        await fetchMissingUsers(userIds: userIds)

        let broadcasts: [DiscoverBroadcast] = filtered.compactMap { record in
            guard let user = cachedUsers[record.userId] else { return nil }
            let track = DiscoverTrack(
                id: record.trackId,
                title: record.trackTitle,
                artist: record.trackArtist,
                album: record.trackAlbum,
                artworkURL: record.trackArtworkURL,
                spotifyTrackURL: record.spotifyTrackURL
            )

            return DiscoverBroadcast(
                id: record.id,
                user: user,
                track: track,
                broadcastedAt: record.broadcastedAt,
                location: record.location,
                distanceMeters: nil
            )
        }

        allBroadcasts = broadcasts
        updateVisibleBroadcasts()
    }

    private func fetchMissingUsers(userIds: Set<String>) async {
        let missing = userIds.filter { cachedUsers[$0] == nil }
        guard !missing.isEmpty else { return }

        await withTaskGroup(of: (String, DiscoverUser?).self) { group in
            for userId in missing {
                group.addTask { [service] in
                    let user = try? await service.fetchDiscoverUser(userId: userId)
                    return (userId, user)
                }
            }

            for await (userId, user) in group {
                if let user {
                    cachedUsers[userId] = user
                }
            }
        }
    }

    private func updateVisibleBroadcasts() {
        let locationAvailable = currentLocation != nil

        var updated = allBroadcasts.filter { broadcast in
            !mutedUserIds.contains(broadcast.user.id) && !mutedTrackIds.contains(broadcast.track.id)
        }

        if let currentLocation {
            updated = updated.map { broadcast in
                var mutable = broadcast
                if let location = broadcast.location {
                    let target = CLLocation(latitude: location.latitude, longitude: location.longitude)
                    let distance = currentLocation.distance(from: target)
                    mutable.distanceMeters = Int(distance)
                } else {
                    mutable.distanceMeters = nil
                }
                return mutable
            }

            updated.sort { lhs, rhs in
                let lhsDistance = lhs.distanceMeters ?? Int.max
                let rhsDistance = rhs.distanceMeters ?? Int.max
                if lhsDistance == rhsDistance {
                    return lhs.broadcastedAt > rhs.broadcastedAt
                }
                return lhsDistance < rhsDistance
            }
        } else if !locationAvailable {
            updated.sort { lhs, rhs in
                lhs.broadcastedAt > rhs.broadcastedAt
            }
        }

        visibleBroadcasts = updated
    }

    private func removeBroadcast(_ broadcast: DiscoverBroadcast) {
        allBroadcasts.removeAll { $0.id == broadcast.id }
        visibleBroadcasts.removeAll { $0.id == broadcast.id }
        dismissTarget = nil
    }

    private func loadMutedPreferencesIfNeeded() {
        guard mutedUserIds.isEmpty && mutedTrackIds.isEmpty else { return }
        guard let uid = service.currentUserId() else { return }
        let defaults = UserDefaults.standard
        let userKey = "discover.mutedUsers.\(uid)"
        let trackKey = "discover.mutedTracks.\(uid)"
        let users = defaults.stringArray(forKey: userKey) ?? []
        let tracks = defaults.stringArray(forKey: trackKey) ?? []
        mutedUserIds = Set(users)
        mutedTrackIds = Set(tracks)
    }

    private func persistMutedPreferences() {
        guard let uid = service.currentUserId() else { return }
        let defaults = UserDefaults.standard
        defaults.set(Array(mutedUserIds), forKey: "discover.mutedUsers.\(uid)")
        defaults.set(Array(mutedTrackIds), forKey: "discover.mutedTracks.\(uid)")
    }

    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

#if DEBUG
extension DiscoverViewModel {
    static func preview() -> DiscoverViewModel {
        let viewModel = DiscoverViewModel()
        viewModel.visibleBroadcasts = [
            DiscoverBroadcast(
                id: "preview-1",
                user: DiscoverUser(
                    id: "user-1",
                    firstName: "Maya",
                    lastName: "Schulz",
                    age: 26,
                    city: "Berlin",
                    gender: "Female",
                    countryCode: "DE",
                    heroPhotoURL: nil,
                    profilePhotoURL: nil,
                    photoURLs: []
                ),
                track: DiscoverTrack(
                    id: "track-1",
                    title: "Midnight Blue",
                    artist: "Luna Park",
                    album: "Night Drives",
                    artworkURL: nil,
                    spotifyTrackURL: nil
                ),
                broadcastedAt: Date(),
                location: LocationPoint(latitude: 52.52, longitude: 13.405),
                distanceMeters: 420
            )
        ]
        return viewModel
    }
}
#endif
