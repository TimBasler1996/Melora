import SwiftUI
import FirebaseAuth

struct SettingsContentView: View {

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
                            Label("Radius", systemImage: "location.circle")
                                .font(.system(size: 16, weight: .regular))
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
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("50 km")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Toggle(isOn: $notifyFriends) {
                    Label("Friend broadcasts", systemImage: "person.2")
                }
            } header: {
                Text("Broadcasts")
            } footer: {
                Text("Get notified when someone you follow or someone nearby starts streaming.")
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
        .background(AppColors.background)
        .tint(AppColors.primary)
        .onChange(of: notifyBroadcast) { _, newValue in
            if newValue { requestNotificationPermission() }
        }
        .onChange(of: notifyFriends) { _, newValue in
            if newValue { requestNotificationPermission() }
        }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                try? Auth.auth().signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - Helpers

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
