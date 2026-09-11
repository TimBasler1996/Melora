import Foundation
import Combine

/// App-wide navigation intents that cross tab boundaries: which tab is
/// selected, a conversation to open, the likes inbox to present. Fed by push
/// notification taps and by in-app calls to action (e.g. "Go live" from an
/// empty Discover feed). Views consume and clear the pending values.
@MainActor
final class AppRouter: ObservableObject {

    /// Tab order on screen: Discover (home), Live, Inbox, Profile. The case
    /// names predate the labels.
    enum Tab: Hashable {
        case now, discover, chats, profile
    }

    enum InboxSection: String, CaseIterable, Identifiable {
        case messages = "Messages"
        case activity = "Activity"
        var id: String { rawValue }
    }

    static let shared = AppRouter()

    /// Discover is home: opening the app shows who is live around you.
    @Published var selectedTab: Tab = .discover

    /// Which half of the Inbox tab is showing.
    @Published var inboxSection: InboxSection = .messages

    /// Conversation the Chats tab should push as soon as it is on screen.
    @Published var pendingConversationId: String?

    /// Ask the Inbox tab to push the message requests list.
    @Published var showMessageRequests: Bool = false

    /// Profile the Profile tab should push (e.g. a new follower).
    @Published var pendingProfileUserId: String?

    private init() {}

    // MARK: - Intents

    func openConversation(_ conversationId: String) {
        selectedTab = .chats
        pendingConversationId = conversationId
    }

    func openActivity() {
        selectedTab = .chats
        inboxSection = .activity
    }

    func openMessageRequests() {
        selectedTab = .chats
        inboxSection = .messages
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
