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

    private let service: DiscoverService
    private let likeService: LikeApiService
    private let chatService: ChatApiService

    private var listener: ListenerRegistration?
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
    }

    deinit {
        Task { @MainActor in
            stopListening()
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
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        isListening = false
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
        }
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
