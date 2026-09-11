import SwiftUI
import AuthenticationServices
import FirebaseAuth
import UserNotifications
import UIKit

struct SettingsContentView: View {

    @EnvironmentObject private var broadcast: BroadcastManager
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("settings.notify.broadcastNearby") private var notifyBroadcast = true
    @AppStorage("settings.notify.friendBroadcasts") private var notifyFriends = true
    @AppStorage("settings.notify.radiusMeters") private var radiusMeters: Double = 5000
    @AppStorage("settings.notify.newLikes") private var notifyLikes = true
    @AppStorage("settings.notify.newMessages") private var notifyMessages = true
    @AppStorage("settings.notify.newFollowers") private var notifyFollowers = true

    @StateObject private var account = AccountService.shared
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showDeleteFinalConfirm = false
    @State private var isLinking = false
    @State private var accountMessage: String?
    @State private var showSpotifyDisconnectConfirm = false
    @State private var notificationsDenied = false
    /// Same key `SpotifyTasteSync.needsReconnect` writes; observed here so
    /// the row updates the moment a sync succeeds.
    @AppStorage("spotifyTaste.needsReconnect") private var needsSpotifyReconnect = false
    /// Same key `SpotifyTasteSync.hidden` mirrors from the user document.
    @AppStorage("spotifyTaste.hidden") private var spotifyTasteHidden = false

    var body: some View {
        List {
            if notificationsDenied {
                notificationsDeniedSection
            }

            // MARK: - Broadcast Notifications
            Section {
                Toggle(isOn: $notifyBroadcast) {
                    Label("Someone goes live nearby", systemImage: "dot.radiowaves.left.and.right")
                }

                if notifyBroadcast {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Notification radius", systemImage: "location.circle")
                                .font(.system(size: 16, weight: .regular))
                            Spacer()
                            Text(formatRadius(radiusMeters))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.primary)
                        }
                        Slider(
                            value: $radiusMeters,
                            in: 100...50_000,
                            step: 100
                        )
                        .tint(AppColors.primary)
                        HStack {
                            Text("100 m")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.secondaryText)
                            Spacer()
                            Text("50 km")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.secondaryText)
                        }
                        Text("You’ll be notified when someone goes live within this distance.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AppColors.secondaryText)
                    }
                }

                Toggle(isOn: $notifyFriends) {
                    Label("People you follow go live", systemImage: "person.2")
                }
            } header: {
                Text("Going live")
            } footer: {
                Text("These settings only control notifications. While you’re live, everyone nearby can see you in Discover.")
            }

            // MARK: - Other Notifications
            Section {
                Toggle(isOn: $notifyLikes) {
                    Label("New likes", systemImage: "heart")
                }

                Toggle(isOn: $notifyMessages) {
                    Label("New messages", systemImage: "message")
                }

                Toggle(isOn: $notifyFollowers) {
                    Label("New followers", systemImage: "person.badge.plus")
                }
            } header: {
                Text("Other Notifications")
            }

            // MARK: - Privacy
            Section {
                NavigationLink {
                    HiddenAndBlockedView()
                } label: {
                    Label("Blocked and hidden", systemImage: "eye.slash")
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("People you blocked and songs or people you hid from Discover.")
            }

            // MARK: - Spotify
            Section {
                if spotifyAuth.isAuthorized {
                    HStack {
                        Label("Spotify connected", systemImage: "music.note")
                        Spacer()
                        Button("Disconnect") {
                            showSpotifyDisconnectConfirm = true
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .buttonStyle(.bordered)
                        .tint(AppColors.primary)
                    }

                    Toggle(isOn: Binding(
                        get: { !spotifyTasteHidden },
                        set: { show in
                            spotifyTasteHidden = !show
                            Task { await SpotifyTasteSync.setHidden(!show) }
                        }
                    )) {
                        Label("Music taste on my profile", systemImage: "music.note.list")
                    }

                    if !spotifyTasteHidden {
                        if needsSpotifyReconnect {
                            Button {
                                spotifyAuth.reconnect()
                            } label: {
                                Label("Reconnect to show your music taste", systemImage: "arrow.clockwise")
                            }
                        } else {
                            Button {
                                Task { await SpotifyTasteSync.syncIfNeeded(force: true) }
                            } label: {
                                Label("Refresh music taste now", systemImage: "arrow.clockwise")
                            }
                        }
                    }
                } else {
                    Button {
                        spotifyAuth.ensureAuthorized()
                    } label: {
                        Label("Connect Spotify", systemImage: "music.note")
                    }
                }
            } header: {
                Text("Spotify")
            } footer: {
                Text(spotifyAuth.isAuthorized
                     ? (spotifyTasteHidden
                        ? "Going live still shares what you’re playing. Your top artists, top tracks and playlists are not shown on your profile."
                        : (needsSpotifyReconnect
                           ? "Your Spotify login is from before profiles showed top artists and playlists. Reconnect once to turn that on."
                           : "Going live shares what you’re playing. Your top artists, top tracks and public playlists show on your profile."))
                     : "Connect Spotify to go live and share what you’re playing.")
            }

            // MARK: - Account
            Section {
                if account.isLinkedWithApple {
                    HStack {
                        Label("Signed in with Apple", systemImage: "checkmark.seal.fill")
                        Spacer()
                        Text("Kept")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.secondaryText)
                    }

                    Button {
                        showSignOutConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your profile lives only on this phone. Sign in with Apple to keep it if you reinstall or switch devices.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AppColors.secondaryText)

                        SignInWithAppleButton(.continue) { request in
                            account.prepareAppleRequest(request)
                        } onCompletion: { result in
                            Task { await linkWithApple(result) }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 44)
                        .clipShape(Capsule())
                        .disabled(isLinking)
                    }
                    .padding(.vertical, 4)
                }

                if let accountMessage {
                    Text(accountMessage)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.secondaryText)
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete profile and data", systemImage: "trash")
                }
            } header: {
                Text("Account")
            } footer: {
                Text(account.isLinkedWithApple
                     ? "Signing out keeps your profile; sign in with Apple again to get it back."
                     : "Deleting removes your profile, photos, likes, chats and followers for good.")
            }

            // MARK: - About
            Section {
                if let url = LegalLinks.privacyPolicy {
                    Link(destination: url) {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                }
                if let url = LegalLinks.termsOfService {
                    Link(destination: url) {
                        Label("Terms of service", systemImage: "doc.text")
                    }
                }
                if let email = LegalLinks.supportEmail, let url = URL(string: "mailto:\(email)") {
                    Link(destination: url) {
                        Label("Contact us", systemImage: "envelope")
                    }
                }
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text(LegalLinks.appVersion)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.secondaryText)
                }
            } header: {
                Text("About")
            } footer: {
                Text("Your location is shared only while you’re live, rounded to a few hundred metres. Blocked people never see you.")
            }
        }
        .confirmationDialog("Delete your profile?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                showDeleteFinalConfirm = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your profile, photos, likes, chats and followers. It cannot be undone.")
        }
        .alert("Really delete?", isPresented: $showDeleteFinalConfirm) {
            Button("Delete my profile", role: .destructive) {
                Task { await deleteProfile() }
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("There is no way to recover a deleted profile.")
        }
        .scrollContentBackground(.hidden)
        .melScreenBackground()
        .tint(AppColors.primary)
        .onChange(of: notifyBroadcast) { _, newValue in
            if newValue { requestNotificationPermission() }
        }
        .onChange(of: notifyFriends) { _, newValue in
            if newValue { requestNotificationPermission() }
        }
        // Like and message pushes are sent by Cloud Functions, which read
        // these flags from the user document.
        .onChange(of: notifyLikes) { _, newValue in
            if newValue { requestNotificationPermission() }
            syncNotificationPreference("notifyLikes", newValue)
        }
        .onChange(of: notifyMessages) { _, newValue in
            if newValue { requestNotificationPermission() }
            syncNotificationPreference("notifyMessages", newValue)
        }
        .onChange(of: notifyFollowers) { _, newValue in
            if newValue { requestNotificationPermission() }
            syncNotificationPreference("notifyFollowers", newValue)
        }
        .confirmationDialog("Disconnect Spotify?", isPresented: $showSpotifyDisconnectConfirm, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) {
                Task {
                    if broadcast.isBroadcasting {
                        await broadcast.stopBroadcasting()
                    }
                    spotifyAuth.disconnect()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(broadcast.isBroadcasting
                 ? "This ends your live session. You can reconnect any time."
                 : "You won’t be able to go live until you reconnect.")
        }
        .task { await refreshNotificationStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshNotificationStatus() } }
        }
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                // Safe for Apple-linked accounts: signing in again restores everything.
                Task { await account.signOut(stopping: broadcast) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You’ll start with an empty profile until you sign in with Apple again.")
        }
    }

    // MARK: - Notifications permission

    private var notificationsDeniedSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Notifications are off", systemImage: "bell.slash")
                    .font(.system(size: 16, weight: .semibold))
                Text("Melora can’t tell you about likes, messages or people going live nearby until you allow notifications in iOS Settings.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColors.secondaryText)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .buttonStyle(.bordered)
                .tint(AppColors.primary)
            }
            .padding(.vertical, 4)
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsDenied = settings.authorizationStatus == .denied
    }

    // MARK: - Account actions

    private func linkWithApple(_ result: Result<ASAuthorization, Error>) async {
        accountMessage = nil
        isLinking = true
        defer { isLinking = false }
        do {
            switch try await account.completeAppleSignIn(result, stopping: broadcast) {
            case .linked:
                accountMessage = "Your profile is now kept with your Apple ID."
            case .switchedToExistingAccount:
                accountMessage = "Welcome back — switched to the profile linked to your Apple ID."
            }
        } catch AccountService.AccountError.cancelled {
            // Nothing to say.
        } catch {
            print("❌ [Account] Apple link failed: \(error)")
            accountMessage = "Couldn’t link your Apple ID. Please try again."
        }
    }

    private func deleteProfile() async {
        do {
            try await AccountService.shared.deleteProfile(stopping: broadcast)
        } catch {
            accountMessage = "Couldn’t delete your profile right now. Please try again."
        }
    }

    // MARK: - Helpers

    private func syncNotificationPreference(_ key: String, _ enabled: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        UserApiService.shared.updateProfile(uid: uid, updates: [key: enabled])
    }

    private func formatRadius(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            let km = meters / 1000.0
            if km == km.rounded() {
                return "\(Int(km)) km"
            }
            return String(format: "%.1f km", km)
        }
    }

    private func requestNotificationPermission() {
        Task {
            _ = await BroadcastNotificationService.requestPermissionIfNeeded()
        }
    }
}
