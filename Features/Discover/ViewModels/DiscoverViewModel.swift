import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

enum DiscoverMode: String, CaseIterable, Identifiable {
    case nearby = "Nearby"
    case friends = "Friends"
    var id: String { rawValue }
}

@MainActor
final class DiscoverViewModel: ObservableObject {

    @Published private(set) var visibleBroadcasts: [DiscoverBroadcast] = []
    @Published var isLoading: Bool = false
    @Published var isSendingLike: Bool = false
    @Published var errorMessage: String?

    /// Transient error from a user action (like/message/follow). Shown as an
    /// alert instead of replacing the feed like `errorMessage` does.
    @Published var actionError: String?

    @Published var selectedBroadcast: DiscoverBroadcast?
    @Published var dismissTarget: DiscoverBroadcast?

    // Discover mode toggle
    @Published var discoverMode: DiscoverMode = .nearby {
        didSet { updateVisibleBroadcasts() }
    }

    // Search radius (km). Only broadcasts within this distance are shown when
    // the user's location is available. Persisted in UserDefaults.
    @Published var maxRadiusKm: Double = DiscoverViewModel.loadRadiusKm() {
        didSet {
            UserDefaults.standard.set(maxRadiusKm, forKey: Self.radiusKey)
            updateVisibleBroadcasts()
        }
    }

    static let radiusKey = "discover.maxRadiusKm"
    static let minRadiusKm: Double = 1
    static let maxRadiusKmAllowed: Double = 500
    static let defaultRadiusKm: Double = 25

    private static func loadRadiusKm() -> Double {
        let stored = UserDefaults.standard.double(forKey: radiusKey)
        guard stored > 0 else { return defaultRadiusKm }
        return min(max(stored, minRadiusKm), maxRadiusKmAllowed)
    }

    // Following state
    @Published private(set) var followingIds: Set<String> = []

    // Track broadcasts that have been liked and messaged
    @Published private(set) var likedBroadcastIds: Set<String> = []
    @Published private(set) var messagedBroadcastIds: Set<String> = []

    private let service: DiscoverService
    private let likeService: LikeApiService
    private let chatService: ChatApiService
    private let followService: FollowApiService

    private var listener: ListenerRegistration?
    private var followListener: ListenerRegistration?
    /// Incremented per snapshot so a slow, older snapshot can't overwrite a newer one.
    private var snapshotGeneration = 0
    private var allBroadcasts: [DiscoverBroadcast] = []
    private var cachedUsers: [String: DiscoverUser] = [:]

    private var mutedUserIds: Set<String> = []
    private var mutedTrackIds: Set<String> = []
    private var blockedUserIds: Set<String> = []
    private var blockListener: ListenerRegistration?
    private var currentLocation: CLLocation?

    private var isListening = false

    init(
        service: DiscoverService = .shared,
        likeService: LikeApiService = .shared,
        chatService: ChatApiService = .shared,
        followService: FollowApiService = .shared
    ) {
        self.service = service
        self.likeService = likeService
        self.chatService = chatService
        self.followService = followService
        // Previews have no Firebase app; reading the uid would crash.
        guard !isRunningInPreview else { return }
        loadLikedBroadcastsFromCache()
        loadMessagedBroadcastsFromCache()
    }

    deinit {
        listener?.remove()
        followListener?.remove()
        blockListener?.remove()
    }

    func startListening() {
        guard !isListening else { return }
        guard !isRunningInPreview else { return }
        isListening = true
        isLoading = true
        errorMessage = nil

        loadMutedPreferencesIfNeeded()

        // Blocked users never appear in the feed.
        blockListener = BlockService.shared.listenToBlockedIds { [weak self] ids in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.blockedUserIds = ids
                self.allBroadcasts.removeAll { ids.contains($0.user.id) }
                self.updateVisibleBroadcasts()
            }
        }

        // Listen to following list for friends mode
        followListener = followService.listenToFollowing { [weak self] (ids: Set<String>) in
            Task { @MainActor [weak self] in
                self?.followingIds = ids
                self?.updateVisibleBroadcasts()
            }
        }

        // The snapshot listener is the single real-time source of truth. Stale
        // documents are hidden client-side (`maxBroadcastAge`) and swept
        // server-side by the `expireStaleBroadcasts` Cloud Function, so no
        // polling fallback is needed.
        listener = service.listenToBroadcasts { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = false
                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.allBroadcasts = []
                    self.visibleBroadcasts = []
                    // Detach everything so Retry / the next appear starts clean
                    // instead of stacking a second set of listeners.
                    self.stopListening()
                case .success(let records):
                    await self.handleBroadcastRecords(records)
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        followListener?.remove()
        followListener = nil
        blockListener?.remove()
        blockListener = nil
        isListening = false
    }

    /// Tear down and re-attach the listeners (Retry button).
    func retry() {
        stopListening()
        startListening()
    }

    /// Manual refresh (pull-to-refresh). Surfaces failures to the user.
    func refresh() async {
        do {
            let records = try await service.fetchBroadcastsOnce()
            await handleBroadcastRecords(records)
            errorMessage = nil
        } catch {
            actionError = "Couldn’t refresh broadcasts. Please try again."
        }
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

    /// Blocks the broadcaster: hidden from Discover, Chats and search from now on.
    func blockUser(for broadcast: DiscoverBroadcast) {
        blockedUserIds.insert(broadcast.user.id)
        removeBroadcast(broadcast)
        Task {
            do {
                try await BlockService.shared.blockUser(userId: broadcast.user.id)
            } catch {
                actionError = "Couldn’t block \(broadcast.user.displayName). Please try again."
            }
        }
    }

    func sendLike(
        for broadcast: DiscoverBroadcast,
        from currentUser: AppUser?,
        message: String?
    ) async throws {
        isSendingLike = true
        defer { isSendingLike = false }
        guard service.currentUserId() != nil else {
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

        let trimmedMessage = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let key = Self.interactionKey(for: broadcast)

        // Mark this broadcast as liked (the like itself succeeded above).
        likedBroadcastIds.insert(key)
        saveLikedBroadcastsToCache()

        if !trimmedMessage.isEmpty {
            // Deliver the typed message into the (new or existing) conversation.
            // This is what the user actually cares about, so failures surface.
            try await chatService.deliverLikeMessage(
                like: like,
                text: trimmedMessage,
                receiverUserId: broadcast.user.id
            )
            messagedBroadcastIds.insert(key)
            saveMessagedBroadcastsToCache()
        } else if like.status == .accepted {
            // Prior relationship: make sure the accepted conversation exists.
            _ = try? await chatService.createConversationStubIfNeeded(
                acceptedLike: like,
                receiverUserId: broadcast.user.id
            )
        }
    }

    /// Likes and messages are per broadcaster *and* track: a new song from the
    /// same person is a new thing to react to.
    private static func interactionKey(for broadcast: DiscoverBroadcast) -> String {
        "\(broadcast.user.id)_\(broadcast.track.id)"
    }

    func isLiked(_ broadcast: DiscoverBroadcast) -> Bool {
        likedBroadcastIds.contains(Self.interactionKey(for: broadcast))
    }

    func hasMessage(_ broadcast: DiscoverBroadcast) -> Bool {
        messagedBroadcastIds.contains(Self.interactionKey(for: broadcast))
    }

    func isFollowing(_ broadcast: DiscoverBroadcast) -> Bool {
        followingIds.contains(broadcast.user.id)
    }

    func toggleFollow(_ broadcast: DiscoverBroadcast) async {
        let userId = broadcast.user.id
        let wasFollowing = followingIds.contains(userId)
        // Optimistic update so the button reacts instantly.
        if wasFollowing {
            followingIds.remove(userId)
        } else {
            followingIds.insert(userId)
        }
        do {
            if wasFollowing {
                try await followService.unfollow(userId: userId)
            } else {
                try await followService.follow(userId: userId)
            }
        } catch {
            // Rollback on failure.
            if wasFollowing {
                followingIds.insert(userId)
            } else {
                followingIds.remove(userId)
            }
            actionError = wasFollowing
                ? "Couldn’t unfollow \(broadcast.user.displayName). Please try again."
                : "Couldn’t follow \(broadcast.user.displayName). Please try again."
        }
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

    /// Broadcasts older than this are considered stale and hidden.
    private static let maxBroadcastAge: TimeInterval = 5 * 60 // 5 minutes

    private func handleBroadcastRecords(_ records: [DiscoverService.BroadcastRecord]) async {
        let currentUserId = service.currentUserId()
        let now = Date()
        let filtered = records.filter { record in
            if let currentUserId, record.userId == currentUserId { return false }
            if mutedUserIds.contains(record.userId) { return false }
            if blockedUserIds.contains(record.userId) { return false }
            if mutedTrackIds.contains(record.trackId) { return false }
            // Hide stale broadcasts (not updated recently)
            let age = now.timeIntervalSince(record.updatedAt ?? record.broadcastedAt)
            if age > Self.maxBroadcastAge { return false }
            return true
        }

        snapshotGeneration += 1
        let generation = snapshotGeneration

        let userIds = Set(filtered.map { $0.userId })
        await fetchMissingUsers(userIds: userIds)

        // A newer snapshot arrived while we were fetching profiles; it will
        // (or already did) apply itself, so don't clobber it with stale data.
        guard generation == snapshotGeneration else { return }

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

            let distanceMeters: Int? = {
                guard let currentLocation, let location = record.location else { return nil }
                let target = CLLocation(latitude: location.latitude, longitude: location.longitude)
                return Int(currentLocation.distance(from: target))
            }()

            return DiscoverBroadcast(
                id: record.id,
                user: user,
                track: track,
                broadcastedAt: record.broadcastedAt,
                location: record.location,
                distanceMeters: distanceMeters
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
            !mutedUserIds.contains(broadcast.user.id)
                && !blockedUserIds.contains(broadcast.user.id)
                && !mutedTrackIds.contains(broadcast.track.id)
        }

        // In friends mode, only show broadcasts from followed users
        if discoverMode == .friends {
            updated = updated.filter { followingIds.contains($0.user.id) }
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

            // Filter to broadcasts within the configured search radius.
            // Broadcasts without a known location stay visible (we can't tell
            // whether they're nearby, and excluding them silently would feel broken).
            let maxMeters = maxRadiusKm * 1000
            updated = updated.filter { broadcast in
                guard let distance = broadcast.distanceMeters else { return true }
                return Double(distance) <= maxMeters
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
