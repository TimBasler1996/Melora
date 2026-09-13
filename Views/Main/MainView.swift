import SwiftUI

/// Root view of the app that shows the main tab bar.
struct MainView: View {

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var currentUserStore: CurrentUserStore
    @EnvironmentObject private var locationService: LocationService
    @StateObject private var chatBadge = ChatBadgeViewModel()
    @StateObject private var activityBadge = LikesBadgeViewModel()
    @State private var routedProfileUserId: String?
    /// The three-page intro, once, the first time someone lands here.
    @State private var showIntro: Bool = !IntroWalkthrough.hasBeenSeen

    var body: some View {
        TabView(selection: $router.selectedTab) {
            DiscoverView()
                .tabItem {
                    Label("Discover", image: "icon-waves")
                }
                .tag(AppRouter.Tab.discover)

            NowPlayingView()
                .tabItem {
                    Label("Live", image: "icon-music")
                }
                .tag(AppRouter.Tab.now)

            InboxView()
                .tabItem {
                    Label("Inbox", image: "icon-tray")
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
                Label("Profile", image: "icon-person")
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
        .fullScreenCover(isPresented: $showIntro, onDismiss: {
            // The intro is down and Discover is visible: now location, which
            // Discover needs right away. Notifications wait for the next
            // launch so two system alerts never stack after "Let's go".
            locationService.requestAuthorizationIfNeeded()
        }) {
            IntroWalkthroughView {
                IntroWalkthrough.markSeen()
                showIntro = false
            }
        }
        .onAppear {
            chatBadge.startListening()
            if let uid = currentUserStore.user?.uid { activityBadge.startListening(userId: uid) }
            // First time the user reaches the main app (after onboarding) is
            // the right moment to ask for notifications, not at cold launch.
            // While the intro is pending nothing is asked; see onDismiss.
            if !showIntro {
                Task { await BroadcastNotificationService.requestPermissionIfNeeded() }
            }
        }
        .onDisappear {
            chatBadge.stopListening()
            activityBadge.stopListening()
        }
    }
}
