import SwiftUI

/// Everything that reaches you, in one tab: messages (requests and chats)
/// and activity (likes on your tracks, new followers). One badge, one place
/// to look, so "did anything happen?" is always a single tap away.
struct InboxView: View {

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MeloraSegmentedControl(
                    options: AppRouter.InboxSection.allCases.map { ($0, $0.rawValue) },
                    selection: $router.inboxSection
                )
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.top, 6)
                .padding(.bottom, 10)

                switch router.inboxSection {
                case .messages:
                    ChatInboxView()
                case .activity:
                    ActivityView()
                }
            }
            .melScreenBackground()
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
