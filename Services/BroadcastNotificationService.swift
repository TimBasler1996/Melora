import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreLocation
import UserNotifications

// MARK: - Notification Delegate (foreground banner display)

final class BroadcastNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

// MARK: - Broadcast Notification Service

@MainActor
final class BroadcastNotificationService: ObservableObject {

    // Settings keys (same as SettingsContentView @AppStorage keys)
    private static let nearbyEnabledKey = "settings.notify.broadcastNearby"
    private static let friendEnabledKey = "settings.notify.friendBroadcasts"
    private static let radiusKey = "settings.notify.radiusMeters"
    private static let notifiedCacheKey = "broadcast.notifiedIds"

    // Dependencies
    private let discoverService: DiscoverService
    private let followService: FollowApiService
    private weak var locationService: LocationService?

    // Listeners
    private var broadcastListener: ListenerRegistration?
    private var followListener: ListenerRegistration?
    private var authListener: AuthStateDidChangeListenerHandle?

    // State
    private var followingIds: Set<String> = []
    private var notifiedBroadcastIds: Set<String> = []
    private var cachedUsers: [String: DiscoverUser] = [:]
    private var isRunning = false

    // Foreground notification delegate (must be retained)
    let notificationDelegate = BroadcastNotificationDelegate()

    init(
        discoverService: DiscoverService = .shared,
        followService: FollowApiService = .shared
    ) {
        self.discoverService = discoverService
        self.followService = followService
        loadNotifiedIds()
    }

    deinit {
        broadcastListener?.remove()
        followListener?.remove()
        if let authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }

    // MARK: - Lifecycle

    func start(locationService: LocationService) {
        guard !isRunning else { return }
        self.locationService = locationService

        // Set up foreground notification display
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // Register notification category
        let category = UNNotificationCategory(
            identifier: "BROADCAST_NOTIFICATION",
            actions: [],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])

        // Start listening once authenticated
        if Auth.auth().currentUser != nil {
            beginListening()
        } else {
            authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                guard let self, user != nil else { return }
                Task { @MainActor in
                    self.beginListening()
                }
            }
        }
    }

    func stop() {
        broadcastListener?.remove()
        broadcastListener = nil
        followListener?.remove()
        followListener = nil
        isRunning = false
    }

    // MARK: - Permission

    static func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        case .authorized, .provisional:
            return true
        default:
            return false
        }
    }

    // MARK: - Private

    private func beginListening() {
        guard !isRunning else { return }
        isRunning = true

        // Listen for new broadcasts
        broadcastListener = discoverService.listenToNewBroadcasts { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let records):
                    await self.processNewBroadcasts(records)
                case .failure:
                    break
                }
            }
        }

        // Listen for following list
        followListener = followService.listenToFollowing { [weak self] ids in
            Task { @MainActor [weak self] in
                self?.followingIds = ids
            }
        }
    }

    private func processNewBroadcasts(_ records: [DiscoverService.BroadcastRecord]) async {
        let currentUserId = discoverService.currentUserId()
        let defaults = UserDefaults.standard
        let nearbyEnabled = defaults.object(forKey: Self.nearbyEnabledKey) as? Bool ?? true
        let friendEnabled = defaults.object(forKey: Self.friendEnabledKey) as? Bool ?? true
        let radiusMeters = defaults.double(forKey: Self.radiusKey)
        let effectiveRadius = radiusMeters > 0 ? radiusMeters : 5000

        for record in records {
            // Skip own broadcasts
            if let currentUserId, record.userId == currentUserId { continue }

            // Skip already notified
            if notifiedBroadcastIds.contains(record.id) { continue }

            let isFriend = followingIds.contains(record.userId)
            let distance = calculateDistance(to: record.location)

            var shouldNotify = false

            // Friend broadcast notification (regardless of distance)
            if friendEnabled && isFriend {
                shouldNotify = true
            }

            // Nearby broadcast notification (within radius)
            if nearbyEnabled, let distance, distance <= effectiveRadius {
                shouldNotify = true
            }

            guard shouldNotify else { continue }

            // Fetch user info for notification content
            let user = await fetchUser(userId: record.userId)
            let displayName = user?.displayName ?? "Someone"

            await sendNotification(
                id: record.id,
                title: "\(displayName) is broadcasting",
                body: "\"\(record.trackTitle)\" by \(record.trackArtist)"
            )

            notifiedBroadcastIds.insert(record.id)
        }

        pruneNotifiedIds()
        saveNotifiedIds()
    }

    private func calculateDistance(to location: LocationPoint?) -> Double? {
        guard let location,
              let currentLoc = locationService?.currentLocationPoint else {
            return nil
        }
        let target = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let current = CLLocation(latitude: currentLoc.latitude, longitude: currentLoc.longitude)
        return current.distance(from: target)
    }

    private func fetchUser(userId: String) async -> DiscoverUser? {
        if let cached = cachedUsers[userId] { return cached }
        let user = try? await discoverService.fetchDiscoverUser(userId: userId)
        if let user { cachedUsers[userId] = user }
        return user
    }

    private func sendNotification(id: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "BROADCAST_NOTIFICATION"
        content.userInfo = ["broadcastId": id, "type": "broadcast"]

        let request = UNNotificationRequest(
            identifier: "broadcast-\(id)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Persistence

    private func loadNotifiedIds() {
        let ids = UserDefaults.standard.stringArray(forKey: Self.notifiedCacheKey) ?? []
        notifiedBroadcastIds = Set(ids)
    }

    private func saveNotifiedIds() {
        UserDefaults.standard.set(Array(notifiedBroadcastIds), forKey: Self.notifiedCacheKey)
    }

    private func pruneNotifiedIds() {
        if notifiedBroadcastIds.count > 500 {
            // Keep only the most recent entries (arbitrary trim)
            let trimmed = Array(notifiedBroadcastIds.suffix(300))
            notifiedBroadcastIds = Set(trimmed)
        }
    }
}
