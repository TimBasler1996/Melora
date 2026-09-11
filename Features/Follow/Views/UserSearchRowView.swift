import SwiftUI

struct UserSearchRowView: View {

    let user: AppUser
    let isFollowing: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(AppFonts.headline())
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            followButton
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    // MARK: - Follow Button

    private var followButton: some View {
        Button(action: onToggleFollow) {
            Text(isFollowing ? "Following" : "Follow")
                .font(AppFonts.subheadline())
                .foregroundColor(isFollowing ? .white.opacity(0.8) : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    isFollowing
                        ? AppColors.surfaceElevated
                        : AppColors.primary
                )
                .clipShape(Capsule())
        }
    }

    // MARK: - Avatar

    private var avatar: some View {
        let urlString = user.photoURLs?.first ?? user.avatarURL

        return Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(AppColors.surfaceElevated)
                            .overlay(ProgressView().tint(.white))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        initialsView
                    @unknown default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        ZStack {
            Circle().fill(AppColors.surfaceElevated)
            Text(user.initials)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var subtitle: String {
        let parts: [String] = [
            user.age.map { "\($0)" },
            (user.city ?? user.hometown).flatMap { $0.isEmpty ? nil : $0 }
        ].compactMap { $0 }
        return parts.isEmpty ? "" : parts.joined(separator: " · ")
    }
}
