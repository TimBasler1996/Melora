import Foundation

struct FollowNotification: Identifiable {
    let id: String
    let fromUserId: String
    let createdAt: Date
    var fromUserDisplayName: String?
    var fromUserAvatarURL: String?
}
