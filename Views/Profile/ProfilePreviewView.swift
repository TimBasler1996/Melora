import SwiftUI
import Foundation

// MARK: - Model used by both Profile tab + Discover sheet

struct ProfilePreviewModel: Equatable {


    /// Lightweight UI model for rendering a profile preview (used in Profile tab + Discover detail sheet)
    struct ProfilePreviewModel: Equatable {

        // MARK: - Main display

        var firstName: String
        var age: Int?
        var city: String?
        var gender: String?
        var countryCode: String?

        // MARK: - Images

        var heroPhotoURL: String?
        var photoURLs: [String]

        // MARK: - Spotify (optional)

        var spotifyIdOrURL: String?

        // MARK: - Derived text

        var titleLine: String {
            let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            let safeName = name.isEmpty ? "Unknown" : name
            if let age { return "\(safeName), \(age)" }
            return safeName
        }

        var subtitleLine: String {
            let c = (city ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return c.isEmpty ? "" : c
        }

        var spotifyProfileURL: URL? {
            let raw = (spotifyIdOrURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return nil }

            // If full URL already
            if let url = URL(string: raw), url.scheme != nil { return url }

            // Otherwise treat as Spotify user id
            return URL(string: "https://open.spotify.com/user/\(raw)")
        }

        // MARK: - Factory

        static func fromUserProfile(_ profile: UserProfile?) -> ProfilePreviewModel {
            guard let profile else {
                return ProfilePreviewModel(
                    firstName: "Your Name",
                    age: nil,
                    city: nil,
                    gender: nil,
                    countryCode: nil,
                    heroPhotoURL: nil,
                    photoURLs: [],
                    spotifyIdOrURL: nil
                )
            }

            // Ensure we don't pass empty strings around
            func clean(_ s: String?) -> String? {
                guard let s else { return nil }
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            }

            // Photos: remove empties
            let photos = profile.photoURLs
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return ProfilePreviewModel(
                firstName: profile.firstName,
                age: profile.age,
                city: clean(profile.city),
                gender: clean(profile.gender),
                countryCode: clean(profile.spotifyCountry ?? profile.countryCode),
                heroPhotoURL: clean(profile.heroPhotoURL),
                photoURLs: photos,
                spotifyIdOrURL: clean(profile.spotifyId)
            )
        }
    }


// Helpers
private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Preview UI (shared)

struct ProfilePreviewView: View {

    enum Density {
        case regular
        case compact

        var heroMinHeight: CGFloat { self == .regular ? 380 : 280 }
        var heroMaxHeight: CGFloat { self == .regular ? 520 : 380 }
        var photoHeight: CGFloat { self == .regular ? 260 : 220 } // ✅ all additional photos same height
        var spacing: CGFloat { self == .regular ? 12 : 10 }
        var titleFont: Font { .system(size: self == .regular ? 24 : 22, weight: .bold, design: .rounded) }
    }

    let model: ProfilePreviewModel
    var density: Density = .regular

    var body: some View {
        VStack(alignment: .leading, spacing: density.spacing) {
            heroCard

            chipsRow

            // ✅ Under each other, fixed size, no overlap
            additionalPhotosList
        }
    }

    // MARK: - Hero (NO crop)

    private var heroCard: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                heroImageNonCropping

                LinearGradient(
                    colors: [Color.black.opacity(0.00), Color.black.opacity(0.62)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 6) {
                    Text(model.titleLine)
                        .font(density.titleFont)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(model.subtitleLine)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.88))
                        .lineLimit(1)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: heroHeight(for: geo.size.width))
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 8)
        }
        .frame(height: density == .regular ? 460 : 340) // container; real height computed inside
    }

    private func heroHeight(for width: CGFloat) -> CGFloat {
        let proposed = width * (density == .regular ? 1.05 : 0.85)
        return min(max(proposed, density.heroMinHeight), density.heroMaxHeight)
    }

    private var heroImageNonCropping: some View {
        Group {
            if let urlString = model.heroPhotoURL?.trimmed, !urlString.isEmpty,
               let url = URL(string: urlString) {

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        heroPlaceholder
                    case .success(let image):
                        ZStack {
                            // Background fill (blur) so we never get ugly bars
                            image
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 18)
                                .opacity(0.35)
                                .clipped()
                                .allowsHitTesting(false)

                            // ✅ Foreground NO-CROP
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                                .transaction { t in t.animation = nil }
                        }
                    case .failure:
                        heroPlaceholder
                    @unknown default:
                        heroPlaceholder
                    }
                }
            } else {
                heroPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary.opacity(0.55), AppColors.secondary.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "person.crop.square.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: - Chips

    private var chipsRow: some View {
        HStack(spacing: 10) {
            if let g = model.gender?.trimmed, !g.isEmpty {
                ProfileChip(text: g, icon: "person.fill")
            }

            if let cc = model.countryCode?.trimmed, !cc.isEmpty {
                ProfileChip(text: cc.uppercased(), icon: "globe")
            }

            if let age = model.age {
                let city = (model.city ?? "").trimmed
                let text = city.isEmpty ? "\(age)" : "\(age) · \(city)"
                ProfileChip(text: text, icon: "location.fill")
            } else if let city = model.city?.trimmed, !city.isEmpty {
                ProfileChip(text: city, icon: "location.fill")
            }

            Spacer(minLength: 0)

            if let spotifyURL = model.spotifyProfileURL {
                Link(destination: spotifyURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Spotify")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(AppColors.tintedBackground.opacity(0.55)))
                    .foregroundColor(AppColors.primaryText)
                }
                .accessibilityLabel("Open Spotify profile")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Additional photos (vertical, fixed size)

    private var additionalPhotosList: some View {
        let urls = model.photoURLs
            .map { $0.trimmed }
            .filter { !$0.isEmpty }

        guard !urls.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            LazyVStack(spacing: 12) {
                ForEach(Array(urls.prefix(10).enumerated()), id: \.offset) { _, url in
                    photoCard(urlString: url)
                }
            }
        )
    }

    private func photoCard(urlString: String) -> some View {
        ZStack {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        photoPlaceholder
                    case .success(let image):
                        // ✅ same size always, no overlap, clean crop inside the tile
                        image
                            .resizable()
                            .scaledToFill()
                            .transaction { t in t.animation = nil }
                    case .failure:
                        photoPlaceholder
                    @unknown default:
                        photoPlaceholder
                    }
                }
            } else {
                photoPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: density.photoHeight) // ✅ fixed height for all
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 8)
    }

    private var photoPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                .fill(AppColors.tintedBackground.opacity(0.35))
            Image(systemName: "photo.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(AppColors.secondaryText)
        }
    }
}
