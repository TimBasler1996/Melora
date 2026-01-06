import SwiftUI

/// Shows and edits the current SocialSound profile backed by Firestore `users/{uid}`.
struct ProfileView: View {

    @EnvironmentObject private var broadcast: BroadcastManager
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager
    @StateObject private var viewModel = ProfileViewModel()

    @State private var didLoadProfile = false

    private let genderOptions: [String] = [
        "",
        "Female",
        "Male",
        "Non-binary",
        "Other"
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                header

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    Text(error)
                        .font(AppFonts.body())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            mainCard
                        }
                        .padding(.horizontal, AppLayout.screenPadding)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .onAppear { loadProfileIfNeeded() }
        .onChange(of: spotifyAuth.isAuthorized) { _ in
            didLoadProfile = false
            loadProfileIfNeeded()
        }
        .onChange(of: viewModel.appUser) { appUser in
            guard let appUser else { return }
            broadcast.updateCurrentUser(userFrom(appUser: appUser))
        }
        .onChange(of: viewModel.saveSucceeded) { succeeded in
            guard succeeded, let appUser = viewModel.appUser else { return }
            broadcast.updateCurrentUser(userFrom(appUser: appUser))
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your Profile")
                .font(AppFonts.title())
                .foregroundColor(.white)

            if spotifyAuth.isAuthorized {
                Text("Based on your Spotify account · tap fields to customize")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Text("Connect Spotify to sync your profile.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.yellow.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 20)
    }

    // MARK: - Main Card

    private var mainCard: some View {
        VStack(spacing: 20) {

            HStack(spacing: 16) {
                avatarCircle

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Display name", text: $viewModel.displayName)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                        .textInputAutocapitalization(.words)

                    if let user = viewModel.appUser {
                        Text("Spotify ID: \(user.spotifyId ?? "—")")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(AppColors.mutedText)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            Divider()

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Country")
                        .font(.caption)
                        .foregroundColor(AppColors.mutedText)

                    TextField("CH", text: $viewModel.countryCode)
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.primaryText)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .frame(width: 80)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Age")
                        .font(.caption)
                        .foregroundColor(AppColors.mutedText)

                    TextField("Age", text: $viewModel.ageString)
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.primaryText)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Gender")
                    .font(.caption)
                    .foregroundColor(AppColors.mutedText)

                Menu {
                    ForEach(genderOptions, id: \.self) { option in
                        Button(option.isEmpty ? "Not specified" : option) {
                            viewModel.gender = option
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.gender.isEmpty ? "Not specified" : viewModel.gender)
                            .foregroundColor(AppColors.primaryText)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(AppColors.mutedText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppColors.tintedBackground)
                    )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Hometown")
                    .font(.caption)
                    .foregroundColor(AppColors.mutedText)

                TextField("Where are you from?", text: $viewModel.hometown)
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.primaryText)
                    .textInputAutocapitalization(.words)
            }

            Button {
                viewModel.saveProfile()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    }
                    Text(viewModel.isSaving ? "Saving…" : "Save profile")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                        .fill(AppColors.primary)
                )
                .foregroundColor(.white)
            }
            .disabled(viewModel.isSaving)

            if viewModel.saveSucceeded {
                Text("Profile saved ✅")
                    .font(AppFonts.footnote())
                    .foregroundColor(.green)
            }
        }
        .padding(AppLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(AppLayout.shadowOpacity),
                        radius: AppLayout.shadowRadius,
                        x: 0,
                        y: 10)
        )
    }

    // MARK: - Avatar

    private var avatarCircle: some View {
        let bestURLString =
            viewModel.appUser?.avatarURL
            ?? viewModel.appUser?.photoURLs?.first

        return Group {
            if let urlString = bestURLString,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Circle().fill(AppColors.tintedBackground)
                            ProgressView().tint(.white)
                        }
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        initialsCircle
                    @unknown default:
                        initialsCircle
                    }
                }
            } else {
                initialsCircle
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
    }

    private var initialsCircle: some View {
        ZStack {
            Circle().fill(AppColors.tintedBackground)
            Text(viewModel.displayName.isEmpty ? "?" : String(viewModel.displayName.prefix(1)))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.primaryText)
        }
    }

    // MARK: - Loading helper

    private func loadProfileIfNeeded() {
        guard !didLoadProfile else { return }
        guard spotifyAuth.isAuthorized else { return }

        let spotifyId = broadcast.currentUser.id
        didLoadProfile = true

        viewModel.loadProfile(
            spotifyId: spotifyId,
            createFromSpotifyIfMissing: true
        )
    }

    // MARK: - Helper to map AppUser -> User (für BroadcastManager)

    private func userFrom(appUser: AppUser) -> User {
        let avatarURL: URL? = {
            if let s = appUser.avatarURL { return URL(string: s) }
            if let s = appUser.photoURLs?.first { return URL(string: s) }
            return nil
        }()

        let stableId = appUser.spotifyId ?? appUser.uid

        return User(
            id: stableId,
            displayName: appUser.displayName,
            avatarURL: avatarURL,
            age: appUser.age,
            countryCode: appUser.countryCode
        )
    }
}

