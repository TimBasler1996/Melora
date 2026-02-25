import SwiftUI
import FirebaseAuth

struct SettingsContentView: View {

    @AppStorage("settings.notify.broadcastNearby") private var notifyBroadcast = true
    @AppStorage("settings.notify.newLikes") private var notifyLikes = true
    @AppStorage("settings.notify.newMessages") private var notifyMessages = true
    @AppStorage("settings.notify.newFollowers") private var notifyFollowers = true

    @State private var showSignOutConfirm = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $notifyBroadcast) {
                    Label("New broadcast nearby", systemImage: "dot.radiowaves.left.and.right")
                }

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
                Text("Notifications")
            } footer: {
                Text("Push notifications will be available in a future update. These preferences will be saved.")
            }

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
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                try? Auth.auth().signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}
