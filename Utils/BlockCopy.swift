import Foundation

/// One wording for blocking, used by every surface that offers it.
///
/// Block is reversible (Settings → Blocked and hidden) but it deletes the
/// shared conversation for both people, and that is not reversible. Both
/// halves have to be in the sentence wherever the action is offered —
/// Discover used to show it under "Hidden songs and people can be restored
/// in Settings", which promised the opposite.
enum BlockCopy {
    static func title(_ name: String) -> String { "Block \(name)?" }
    static let button = "Block"
    static let message = "They won’t appear in Discover, chats or search, and your chat with them is deleted for both of you. You can unblock them in Settings."
    static func failure(_ name: String) -> String { "Couldn’t block \(name). Please try again." }
    static let errorTitle = "Couldn’t do that"
    /// When the name is unknown.
    static let fallbackName = "this person"
}
