import Foundation

#if DEBUG
extension UserProfile {
    static var mockPreview: UserProfile {
        UserProfile(
            uid: "preview-uid",
            firstName: "Tim",
            lastName: "Basler",
            city: "Zürich",
            birthday: Calendar.current.date(byAdding: .year, value: -20, to: Date()),
            gender: "Male",
            photoURLs: [
                "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1400&q=70",
                "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?auto=format&fit=crop&w=1400&q=70",
                "https://images.unsplash.com/photo-1503023345310-bd7c1de61c7d?auto=format&fit=crop&w=1400&q=70"
            ],
            spotifyId: "spotifyuser123",
            spotifyCountry: "CH",
            countryCode: "CH",
            spotifyAvatarURL: nil,
            spotifyDisplayName: "Tim B.",
            profileCompleted: true
        )
    }
}
#endif
