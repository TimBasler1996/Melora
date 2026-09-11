import SwiftUI

/// Root view of the app that shows the main tab bar.
struct MainView: View {

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var currentUserStore: CurrentUserStore
    @StateObject private var chatBadge = ChatBadgeViewModel()
    @StateObject private var activityBadge = LikesBadgeViewModel()
    @State private var routedProfileUserId: String?

    var body: some View {
        TabView(selection: $router.selectedTab) {
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "dot.radiowaves.left.and.right")
                }
                .tag(AppRouter.Tab.discover)

            NowPlayingView()
                .tabItem {
                    Label("Live", systemImage: "music.note")
                }
                .tag(AppRouter.Tab.now)

            InboxView()
                .tabItem {
                    Label("Inbox", systemImage: "tray")
                }
                .badge(chatBadge.unreadCount + activityBadge.unreadCount)
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
        .onChange(of: currentUserStore.user?.uid) { _, uid in
            activityBadge.stopListening()
            if let uid { activityBadge.startListening(userId: uid) }
        }
        .onAppear {
            chatBadge.startListening()
            if let uid = currentUserStore.user?.uid { activityBadge.startListening(userId: uid) }
            // First time the user reaches the main app (after onboarding) is
            // the right moment to ask for notifications, not at cold launch.
            Task { await BroadcastNotificationService.requestPermissionIfNeeded() }
        }
        .onDisappear {
            chatBadge.stopListening()
            activityBadge.stopListening()
        }
    }
}
