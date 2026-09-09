import SwiftUI
import AuthenticationServices
import FirebaseAuth

struct SettingsContentView: View {

    @EnvironmentObject private var broadcast: BroadcastManager

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

    var body: some View {
        List {
            // MARK: - Broadcast Notifications
            Section {
                Toggle(isOn: $notifyBroadcast) {
                    Label("Nearby broadcasts", systemImage: "dot.radiowaves.left.and.right")
                }

                if notifyBroadcast {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Notification radius", systemImage: "location.circle")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                            Spacer()
                            Text(formatRadius(radiusMeters))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
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
                        Text("You'll be notified when someone starts broadcasting within this distance.")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(AppColors.secondaryText)
                    }
                }

                Toggle(isOn: $notifyFriends) {
                    Label("Friend broadcasts", systemImage: "person.2")
                }
            } header: {
                Text("Broadcasts")
            } footer: {
                Text("These settings control when you receive notifications. Your broadcast is always visible to everyone on the map.")
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
                            .font(.system(size: 13, weight: .regular, design: .rounded))
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

    // MARK: - Account actions

    private func linkWithApple(_ result: Result<ASAuthorization, Error>) async {
        accountMessage = nil
        isLinking = true
        defer { isLinking = false }
        do {
            switch try await account.completeAppleSignIn(result) {
            case .linked:
                accountMessage = "Your profile is now kept with your Apple ID."
            case .switchedToExistingAccount:
                accountMessage = "Welcome back — switched to the profile linked to your Apple ID."
            }
        } catch AccountService.AccountError.cancelled {
            // Nothing to say.
        } catch {
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
