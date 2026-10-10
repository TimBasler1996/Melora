import Foundation
import Testing

/// What a card says about a person when the data is incomplete. Every one of
/// these fallbacks was once a placeholder leaking onto a real screen.
struct DiscoverModelTests {

    private func user(first: String = "Lena", last: String = "K", city: String = "Zürich") -> DiscoverUser {
        DiscoverUser(
            id: "u1", firstName: first, lastName: last, age: 22, city: city,
            gender: nil, countryCode: "CH", heroPhotoURL: nil,
            profilePhotoURL: nil, photoURLs: []
        )
    }

    @Test("A name is assembled from the parts that exist")
    func displayName() {
        #expect(user().displayName == "Lena K")
        #expect(user(last: "").displayName == "Lena")
        #expect(user(first: "", last: "").displayName == "New member")
        #expect(user(first: "  ", last: " ").displayName == "New member")
    }

    @Test("The hero photo wins, then the profile photo, then the first of the rest")
    func photoPrecedence() {
        let base = DiscoverUser(
            id: "u1", firstName: "A", lastName: "B", age: nil, city: "X",
            gender: nil, countryCode: nil,
            heroPhotoURL: "hero", profilePhotoURL: "profile", photoURLs: ["first"]
        )
        #expect(base.primaryPhotoURL == "hero")

        let noHero = DiscoverUser(
            id: "u1", firstName: "A", lastName: "B", age: nil, city: "X",
            gender: nil, countryCode: nil,
            heroPhotoURL: "   ", profilePhotoURL: "profile", photoURLs: ["first"]
        )
        #expect(noHero.primaryPhotoURL == "profile")

        let onlyList = DiscoverUser(
            id: "u1", firstName: "A", lastName: "B", age: nil, city: "X",
            gender: nil, countryCode: nil,
            heroPhotoURL: nil, profilePhotoURL: nil, photoURLs: ["first"]
        )
        #expect(onlyList.primaryPhotoURL == "first")
    }

    @Test("How long ago someone was live reads in the right unit")
    func lastSeenText() {
        func broadcast(secondsAgo: TimeInterval) -> DiscoverBroadcast {
            DiscoverBroadcast(
                id: "b", user: user(),
                track: DiscoverTrack(id: "t", title: "Nights", artist: "Frank Ocean",
                                     album: nil, artworkURL: nil, spotifyTrackURL: nil),
                broadcastedAt: Date(), location: nil, distanceMeters: nil,
                isLive: false, lastSeenAt: Date().addingTimeInterval(-secondsAgo)
            )
        }
        #expect(broadcast(secondsAgo: 30).lastSeenText == "just now")
        #expect(broadcast(secondsAgo: 60 * 12).lastSeenText == "12 min ago")
        #expect(broadcast(secondsAgo: 3600 * 3).lastSeenText == "3 h ago")
        #expect(broadcast(secondsAgo: 3600 * 30).lastSeenText == "yesterday")
    }
}
