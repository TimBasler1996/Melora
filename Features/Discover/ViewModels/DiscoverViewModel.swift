import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

enum DiscoverMode: String, CaseIterable, Identifiable {
    case nearby = "Nearby"
    case friends = "Following"
    var id: String { rawValue }
}

@MainActor
final class DiscoverViewModel: ObservableObject {

    /// People broadcasting right now, inside the radius, sorted by distance.
    @Published private(set) var visibleBroadcasts: [DiscoverBroadcast] = []

    /// People who were live in the last 24 h but aren't right now. Shown so
    /// Discover has something to offer in a quiet moment; not radius-filtered.
    @Published private(set) var recentBroadcasts: [DiscoverBroadcast] = []

    /// Live broadcasts hidden only because they are outside the radius.
    @Published private(set) var liveOutsideRadiusCount: Int = 0

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

    private let hidden = HiddenContentStore.shared
    private var mutedUserIds: Set<String> { hidden.mutedUserIds }
    private var mutedTrackIds: Set<String> { hidden.mutedTrackIds }
    private var blockedUserIds: Set<String> = []

    /// A just-performed hide/block the user can take back for a few seconds.
    struct UndoAction: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let perform: () -> Void
        static func == (lhs: UndoAction, rhs: UndoAction) -> Bool { lhs.id == rhs.id }
    }
    @Published var undo: UndoAction?
    private var undoTimeout: Task<Void, Never>?
    /// The action whose server write is waiting for the undo window.
    private var pendingUndo: PendingUndo?
    /// Blocks applied locally but not yet written (inside the undo window).
    private var pendingBlockIds: Set<String> = []
    private var hiddenObserver: AnyCancellable?

    private final class PendingUndo {
        let action: UndoAction
        let commit: (() async -> Void)?
        var undone = false
        init(action: UndoAction, commit: (() async -> Void)?) {
            self.action = action
            self.commit = commit
        }
    }
    private static let undoWindow: UInt64 = 5 * 1_000_000_000
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

    // MARK: - Listening

    func startListening() {
        guard !isListening else { return }
        guard !isRunningInPreview else { return }
        isListening = true
        isLoading = true
        errorMessage = nil

        hidden.loadIfNeeded()
        // "Show again" in Settings must reach the feed without a new snapshot.
        hiddenObserver = hidden.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateVisibleBroadcasts() }

        // Blocked users never appear in the feed.
        blockListener = BlockService.shared.listenToBlockedIds { [weak self] ids in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.blockedUserIds = ids.union(self.pendingBlockIds)
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
        // documents are demoted to "recently live" client-side and swept
        // server-side by the `expireStaleBroadcasts` Cloud Function.
        listener = service.listenToBroadcasts { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = false
                switch result {
                case .failure(let error):
                    self.errorMessage = UserFacingError.message(for: error, fallback: "Couldn’t load Discover. Check your connection and try again.")
                    self.allBroadcasts = []
                    self.visibleBroadcasts = []
                    self.recentBroadcasts = []
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
        hiddenObserver = nil
        isListening = false
        flushPendingUndo()
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
            actionError = "Couldn’t refresh. Please try again."
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

    // MARK: - Radius helpers

    /// Grows the radius just enough to include the nearest live broadcast
    /// that is currently hidden by it.
    func widenRadiusToNearestLive() {
        let hidden = filteredBase().filter { $0.isLive && !passesRadius($0) }
        guard let nearest = hidden.compactMap(\.distanceMeters).min() else {
            maxRadiusKm = Self.maxRadiusKmAllowed
            return
        }
        let km = ceil(Double(nearest) / 1000) + 1
        maxRadiusKm = min(max(km, Self.minRadiusKm), Self.maxRadiusKmAllowed)
    }

    // MARK: - Dismiss / mute / block

    func requestDismiss(for broadcast: DiscoverBroadcast) {
        dismissTarget = broadcast
    }

    func cancelDismiss() {
        dismissTarget = nil
    }

    func muteUser(for broadcast: DiscoverBroadcast) {
        hidden.hideUser(id: broadcast.user.id, name: broadcast.user.displayName)
        dismissTarget = nil
        updateVisibleBroadcasts()
        offerUndo("\(broadcast.user.displayName) hidden") { [weak self] in
            self?.hidden.unhideUser(id: broadcast.user.id)
            self?.updateVisibleBroadcasts()
        }
    }

    func muteTrack(for broadcast: DiscoverBroadcast) {
        hidden.hideTrack(id: broadcast.track.id, title: broadcast.track.title, artist: broadcast.track.artist)
        dismissTarget = nil
        updateVisibleBroadcasts()
        offerUndo("“\(broadcast.track.title)” hidden") { [weak self] in
            self?.hidden.unhideTrack(id: broadcast.track.id)
            self?.updateVisibleBroadcasts()
        }
    }

    /// Blocks the broadcaster: hidden from Discover, Chats and search from
    /// now on. The server write waits for the undo window so a slip of the
    /// thumb costs nothing.
    func blockUser(for broadcast: DiscoverBroadcast) {
        let userId = broadcast.user.id
        let name = broadcast.user.displayName

        blockedUserIds.insert(userId)
        pendingBlockIds.insert(userId)
        dismissTarget = nil
        updateVisibleBroadcasts()

        // The commit must not depend on `self`: it has to land even if this
        // view model goes away while the toast is up.
        let chatService = self.chatService
        let currentUserId = service.currentUserId() ?? ""

        offerUndo("\(name) blocked") { [weak self] in
            self?.pendingBlockIds.remove(userId)
            self?.blockedUserIds.remove(userId)
            self?.updateVisibleBroadcasts()
        } commit: { [weak self] in
            do {
                try await BlockService.shared.blockUser(userId: userId)
                // Any chat with them is closed too, so no unread badge lingers
                // on a conversation the user can no longer see.
                let convoId = chatService.conversationId(for: userId, and: currentUserId)
                try? await chatService.deleteConversation(conversationId: convoId)
                self?.pendingBlockIds.remove(userId)
            } catch {
                self?.pendingBlockIds.remove(userId)
                self?.blockedUserIds.remove(userId)
                self?.updateVisibleBroadcasts()
                self?.actionError = "Couldn’t block \(name). Please try again."
            }
        }
    }

    // MARK: - Undo

    /// Shows an undo toast. `commit` (if any) runs once the window passes
    /// without an undo; the local effect has already been applied. A second
    /// action inside the window commits the first one right away.
    private func offerUndo(_ message: String, undo: @escaping () -> Void, commit: (() async -> Void)? = nil) {
        flushPendingUndo()

        let action = UndoAction(message: message, perform: undo)
        let pending = PendingUndo(action: action, commit: commit)
        pendingUndo = pending
        self.undo = action

        undoTimeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.undoWindow)
            guard !Task.isCancelled, !pending.undone else { return }
            if let self, self.undo == action { self.undo = nil }
            if let self, self.pendingUndo === pending { self.pendingUndo = nil }
            await pending.commit?()
        }
    }

    func performUndo() {
        guard let pending = pendingUndo, !pending.undone else { return }
        pending.undone = true
        undoTimeout?.cancel()
        undoTimeout = nil
        pendingUndo = nil
        undo = nil
        pending.action.perform()
    }

    /// Ends the current undo window early and runs its commit (if not undone).
    private func flushPendingUndo() {
        undoTimeout?.cancel()
        undoTimeout = nil
        undo = nil
        guard let pending = pendingUndo else { return }
        pendingUndo = nil
        guard !pending.undone, let commit = pending.commit else { return }
        Task { await commit() }
    }

    // MARK: - Like / message

    /// Sends a like (optionally with a message). The heart is shown
    /// optimistically and rolled back if the like fails, so the card never
    /// claims a like that didn't happen.
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

        let key = Self.interactionKey(for: broadcast)
        let wasLiked = likedBroadcastIds.contains(key)
        // A plain like flips the heart optimistically; a message send has its
        // own spinner, so the heart waits for the server and can't flash red.
        let isPlainLike = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isPlainLike { likedBroadcastIds.insert(key) }

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

        let like: TrackLike
        do {
            like = try await likeService.likeBroadcastTrack(
                fromUser: currentUser,
                toUser: receiverUser,
                track: track,
                sessionLocation: nil,
                placeLabel: nil,
                message: message
            )
        } catch {
            if !wasLiked { likedBroadcastIds.remove(key) }
            throw error
        }
        likedBroadcastIds.insert(key)
        saveLikedBroadcastsToCache()

        let trimmedMessage = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMessage.isEmpty {
            // Deliver the typed message into the (new or existing) conversation.
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

    /// Turns an error from `sendLike` into the alert text. Our own errors
    /// carry a user-facing explanation; anything else gets the fallback.
    func presentActionError(_ error: Error, fallback: String) {
        if error is LikeApiService.LikeError || error is ChatApiService.ChatError {
            actionError = error.localizedDescription
        } else {
            actionError = UserFacingError.message(for: error, fallback: fallback)
        }
    }

    /// The conversation id for a broadcaster, so the card can offer "Open chat".
    func conversationId(with broadcast: DiscoverBroadcast) async -> String? {
        guard let me = service.currentUserId() else { return nil }
        return chatService.conversationId(for: me, and: broadcast.user.id)
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
        let cached = UserDefaults.standard.stringArray(forKey: "discover.likedBroadcasts.\(uid)") ?? []
        likedBroadcastIds = Set(cached)
    }

    private func saveLikedBroadcastsToCache() {
        guard let uid = service.currentUserId() else { return }
        UserDefaults.standard.set(Array(likedBroadcastIds), forKey: "discover.likedBroadcasts.\(uid)")
    }

    private func loadMessagedBroadcastsFromCache() {
        guard let uid = service.currentUserId() else { return }
        let cached = UserDefaults.standard.stringArray(forKey: "discover.messagedBroadcasts.\(uid)") ?? []
        messagedBroadcastIds = Set(cached)
    }

    private func saveMessagedBroadcastsToCache() {
        guard let uid = service.currentUserId() else { return }
        UserDefaults.standard.set(Array(messagedBroadcastIds), forKey: "discover.messagedBroadcasts.\(uid)")
    }

    func selectBroadcast(_ broadcast: DiscoverBroadcast) {
        selectedBroadcast = broadcast
    }

    // MARK: - Records → broadcasts

    /// A live broadcast not refreshed within this window is shown as recent.
    private static let maxLiveAge: TimeInterval = 5 * 60
    /// How many recently-live rows to keep.
    private static let maxRecentRows = 20

    private func handleBroadcastRecords(_ records: [DiscoverService.BroadcastRecord]) async {
        let currentUserId = service.currentUserId()
        let now = Date()
        let filtered = records.filter { record in
            if let currentUserId, record.userId == currentUserId { return false }
            let age = now.timeIntervalSince(record.updatedAt ?? record.broadcastedAt)
            return age <= DiscoverService.recentWindow
        }

        snapshotGeneration += 1
        let generation = snapshotGeneration

        // Profiles of people we hide anyway are not worth a read.
        let userIds = Set(filtered.map { $0.userId })
            .subtracting(blockedUserIds)
            .subtracting(mutedUserIds)
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

            let lastUpdate = record.updatedAt ?? record.broadcastedAt
            let isLive = record.isLive && now.timeIntervalSince(lastUpdate) <= Self.maxLiveAge

            return DiscoverBroadcast(
                id: record.id,
                user: user,
                track: track,
                broadcastedAt: record.broadcastedAt,
                location: record.location,
                distanceMeters: nil,
                isLive: isLive,
                lastSeenAt: isLive ? lastUpdate : (record.endedAt ?? lastUpdate)
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

    private func passesRadius(_ broadcast: DiscoverBroadcast) -> Bool {
        // Broadcasts without a known distance stay visible: we can't tell
        // whether they're nearby, and hiding them silently would feel broken.
        guard let distance = broadcast.distanceMeters else { return true }
        return Double(distance) <= maxRadiusKm * 1000
    }

    /// Mute/block/mode filter with distances applied. `allBroadcasts` itself
    /// is left untouched so switching modes never loses anything.
    private func filteredBase() -> [DiscoverBroadcast] {
        var base = allBroadcasts.filter { broadcast in
            !mutedUserIds.contains(broadcast.user.id)
                && !blockedUserIds.contains(broadcast.user.id)
                && !mutedTrackIds.contains(broadcast.track.id)
        }

        // In friends mode, only show broadcasts from followed users
        if discoverMode == .friends {
            base = base.filter { followingIds.contains($0.user.id) }
        }

        // Distances only when we know where we are; otherwise none at all,
        // so a stale "about 3 km" never outlives the location fix.
        return base.map { broadcast in
            var mutable = broadcast
            if let currentLocation, let location = broadcast.location {
                let target = CLLocation(latitude: location.latitude, longitude: location.longitude)
                mutable.distanceMeters = Int(currentLocation.distance(from: target))
            } else {
                mutable.distanceMeters = nil
            }
            return mutable
        }
    }

    private func updateVisibleBroadcasts() {
        let base = filteredBase()

        // Live now: radius-filtered, nearest first.
        let live = base.filter(\.isLive)
        var visible = live
        // People you follow are shown wherever they are; the radius only
        // narrows the Nearby feed.
        if currentLocation != nil, discoverMode == .nearby {
            visible = live.filter(passesRadius)
            liveOutsideRadiusCount = live.count - visible.count
            visible.sort { lhs, rhs in
                let l = lhs.distanceMeters ?? Int.max
                let r = rhs.distanceMeters ?? Int.max
                if l == r { return lhs.broadcastedAt > rhs.broadcastedAt }
                return l < r
            }
        } else {
            liveOutsideRadiusCount = 0
            visible.sort { lhs, rhs in
                let l = lhs.distanceMeters ?? Int.max
                let r = rhs.distanceMeters ?? Int.max
                if l == r { return lhs.broadcastedAt > rhs.broadcastedAt }
                return l < r
            }
        }
        visibleBroadcasts = visible

        // Recently live: most recent first, not radius-filtered.
        recentBroadcasts = Array(
            base.filter { !$0.isLive }
                .sorted { $0.lastSeenAt > $1.lastSeenAt }
                .prefix(Self.maxRecentRows)
        )
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
