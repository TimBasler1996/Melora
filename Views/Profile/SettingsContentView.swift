import SwiftUI
import FirebaseAuth

struct SettingsContentView: View {

    @EnvironmentObject private var broadcast: BroadcastManager

    @AppStorage("settings.notify.broadcastNearby") private var notifyBroadcast = true
    @AppStorage("settings.notify.friendBroadcasts") private var notifyFriends = true
    @AppStorage("settings.notify.radiusMeters") private var radiusMeters: Double = 5000
    @AppStorage("settings.notify.newLikes") private var notifyLikes = true
    @AppStorage("settings.notify.newMessages") private var notifyMessages = true
    @AppStorage("settings.notify.newFollowers") private var notifyFollowers = true

    @State private var showSignOutConfirm = false

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
            Section("Account") {
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
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
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                // Tears down the session and provisions a fresh anonymous
                // user; the app root reacts to the auth change.
                Task { await FirebaseAuthBootstrap.signOut(stopping: broadcast) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
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
