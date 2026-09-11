import Foundation
import Combine

/// App-wide navigation intents that cross tab boundaries: which tab is
/// selected, a conversation to open, the likes inbox to present. Fed by push
/// notification taps and by in-app calls to action (e.g. "Go live" from an
/// empty Discover feed). Views consume and clear the pending values.
@MainActor
final class AppRouter: ObservableObject {

    enum Tab: Hashable {
        case now, discover, chats, profile
    }

    static let shared = AppRouter()

    @Published var selectedTab: Tab = .now

    /// Conversation the Chats tab should push as soon as it is on screen.
    @Published var pendingConversationId: String?

    /// Ask the visible tab to present the Activity feed (likes, followers).
    @Published var showActivity: Bool = false

    /// Ask the Chats tab to show the message requests list.
    @Published var showMessageRequests: Bool = false

    /// Profile the Profile tab should push (e.g. a new follower).
    @Published var pendingProfileUserId: String?

    private init() {}

    // MARK: - Intents

    func openConversation(_ conversationId: String) {
        selectedTab = .chats
        pendingConversationId = conversationId
    }

    /// The bell on whichever tab is selected answers this, so the feed
    /// always opens on screen.
    func openActivity() {
        showActivity = true
    }

    func openMessageRequests() {
        selectedTab = .chats
        showMessageRequests = true
    }

    func goLive() {
        selectedTab = .now
    }

    func openProfile(_ userId: String) {
        selectedTab = .profile
        pendingProfileUserId = userId
    }

    // MARK: - Push notifications

    /// Routes a tapped notification. `userInfo` is the FCM payload; the
    /// `type` and ids are set by the Cloud Functions in functions/src/index.ts.
    func handleNotification(userInfo: [AnyHashable: Any]) {
        let type = userInfo["type"] as? String ?? ""
        let conversationId = userInfo["conversationId"] as? String

        switch type {
        case "chatMessage", "messageRequest", "likeAccepted":
            if let conversationId, !conversationId.isEmpty {
                openConversation(conversationId)
            } else {
                selectedTab = .chats
            }
        case "likeReceived":
            openActivity()
        case "newFollower":
            if let userId = userInfo["userId"] as? String, !userId.isEmpty {
                openProfile(userId)
            } else {
                selectedTab = .profile
            }
        case "broadcast":
            selectedTab = .discover
        default:
            break
        }
    }
}
