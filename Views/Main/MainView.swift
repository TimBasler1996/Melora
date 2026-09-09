import SwiftUI

/// Root view of the app that shows the main tab bar.
struct MainView: View {

    @EnvironmentObject private var router: AppRouter
    @StateObject private var chatBadge = ChatBadgeViewModel()
    @State private var routedProfileUserId: String?

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NowPlayingView()
                .tabItem {
                    Label("Now", systemImage: "music.note")
                }
                .tag(AppRouter.Tab.now)

            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "dot.radiowaves.left.and.right")
                }
                .tag(AppRouter.Tab.discover)

            ChatInboxView()
                .tabItem {
                    Label("Chats", systemImage: "message")
                }
                .badge(chatBadge.unreadCount)
                .tag(AppRouter.Tab.chats)

            NavigationStack {
                ProfileView()
                    .navigationDestination(item: $routedProfileUserId) { userId in
                        UserProfilePreviewView(userId: userId)
                    }
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            .tag(AppRouter.Tab.profile)
        }
        .tint(AppColors.primary)
        .onChange(of: router.pendingProfileUserId) { _, userId in
            guard let userId else { return }
            router.pendingProfileUserId = nil
            routedProfileUserId = userId
        }
        .onAppear {
            chatBadge.startListening()
            // First time the user reaches the main app (after onboarding) is
            // the right moment to ask for notifications, not at cold launch.
            Task { await BroadcastNotificationService.requestPermissionIfNeeded() }
        }
        .onDisappear { chatBadge.stopListening() }
    }
}
