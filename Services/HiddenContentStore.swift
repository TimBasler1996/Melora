import Foundation
import FirebaseAuth

/// People and songs the user chose to hide from Discover ("Not interested").
/// Kept per account on the device, with names so the list in Settings is
/// readable and every hide can be undone.
@MainActor
final class HiddenContentStore: ObservableObject {

    static let shared = HiddenContentStore()

    struct HiddenUser: Identifiable, Codable, Equatable {
        let id: String
        var name: String
    }

    struct HiddenTrack: Identifiable, Codable, Equatable {
        let id: String
        var title: String
        var artist: String
    }

    @Published private(set) var users: [HiddenUser] = []
    @Published private(set) var tracks: [HiddenTrack] = []

    private var loadedForUid: String?

    private init() {}

    var mutedUserIds: Set<String> { Set(users.map(\.id)) }
    var mutedTrackIds: Set<String> { Set(tracks.map(\.id)) }

    // MARK: - Loading

    /// Loads the current account's lists (once per account).
    func loadIfNeeded() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard uid != loadedForUid else { return }
        loadedForUid = uid

        let defaults = UserDefaults.standard
        let decoder = JSONDecoder()

        if let data = defaults.data(forKey: Self.usersKey(uid)),
           let decoded = try? decoder.decode([HiddenUser].self, from: data) {
            users = decoded
        } else {
            // Older builds stored bare id arrays without names.
            let legacy = defaults.stringArray(forKey: "discover.mutedUsers.\(uid)") ?? []
            users = legacy.map { HiddenUser(id: $0, name: "Someone") }
        }

        if let data = defaults.data(forKey: Self.tracksKey(uid)),
           let decoded = try? decoder.decode([HiddenTrack].self, from: data) {
            tracks = decoded
        } else {
            let legacy = defaults.stringArray(forKey: "discover.mutedTracks.\(uid)") ?? []
            tracks = legacy.map { HiddenTrack(id: $0, title: "Hidden song", artist: "") }
        }
    }

    // MARK: - Mutations

    func hideUser(id: String, name: String) {
        loadIfNeeded()
        guard !users.contains(where: { $0.id == id }) else { return }
        users.append(HiddenUser(id: id, name: name))
        persist()
    }

    func unhideUser(id: String) {
        users.removeAll { $0.id == id }
        persist()
    }

    func hideTrack(id: String, title: String, artist: String) {
        loadIfNeeded()
        guard !tracks.contains(where: { $0.id == id }) else { return }
        tracks.append(HiddenTrack(id: id, title: title, artist: artist))
        persist()
    }

    func unhideTrack(id: String) {
        tracks.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Persistence

    private static func usersKey(_ uid: String) -> String { "hidden.users.\(uid)" }
    private static func tracksKey(_ uid: String) -> String { "hidden.tracks.\(uid)" }

    private func persist() {
        guard let uid = loadedForUid ?? Auth.auth().currentUser?.uid else { return }
        let encoder = JSONEncoder()
        let defaults = UserDefaults.standard
        if let data = try? encoder.encode(users) { defaults.set(data, forKey: Self.usersKey(uid)) }
        if let data = try? encoder.encode(tracks) { defaults.set(data, forKey: Self.tracksKey(uid)) }
    }
}
