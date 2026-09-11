import SwiftUI
import FirebaseAuth

/// Unified profile view used everywhere a user's profile is opened from.
/// Shows the same layout for any user; renders a Follow / Following button
/// and a Block / Report menu when viewing someone else's profile.
struct UserProfilePreviewView: View {

    let userId: String
    /// Off when the profile was opened from that person's chat.
    var showsMessageButton: Bool = true

    @StateObject private var vm = UserProfilePreviewViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showBlockConfirm = false
    @State private var showReportSheet = false

    var body: some View {
        ZStack {
            if vm.isLoading {
                loadingState
            } else if let error = vm.errorMessage {
                errorState(error)
            } else if let user = vm.user {
                ScrollView(.vertical) {
                    VStack(spacing: 16) {
                        if !vm.isOwnProfile {
                            followBar
                        }

                        let previewData = ProfilePreviewData.from(
                            appUser: user,
                            followerCount: vm.followerCount,
                            likesReceivedCount: vm.likesReceivedCount
                        )
                        SharedProfilePreviewView(data: previewData)
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .melScreenBackground()
        .navigationTitle(vm.user?.displayName ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !vm.isOwnProfile, vm.user != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showReportSheet = true
                        } label: {
                            Label("Report", systemImage: "flag")
                        }
                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label("Block", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("More")
                }
            }
        }
        .confirmationDialog("Block \(vm.user?.displayName ?? "this person")?", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                Task {
                    if await vm.block() { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won’t appear in your Discover feed, chats or search. You can unblock them in Settings.")
        }
        .sheet(isPresented: $showReportSheet) {
            ReportUserSheet(userId: userId, userName: vm.user?.displayName ?? "this person")
        }
        .alert(
            "Couldn’t do that",
            isPresented: Binding(
                get: { vm.actionError != nil },
                set: { if !$0 { vm.actionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { vm.actionError = nil }
        } message: {
            Text(vm.actionError ?? "")
        }
        .task {
            await vm.load(userId: userId)
        }
    }

    // MARK: - Follow + Message

    /// The two things you can do with a person: follow them (see when they
    /// go live) or message them (a request until they reply).
    private var followBar: some View {
        HStack(spacing: 10) {
            Button {
                Task { await vm.toggleFollow() }
            } label: {
                HStack(spacing: 6) {
                    if vm.isFollowLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: vm.isFollowing ? AppColors.primaryText : .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: vm.isFollowing ? "checkmark" : "plus")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(vm.isFollowing ? "Following" : "Follow")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundColor(vm.isFollowing ? AppColors.primaryText : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                        .fill(vm.isFollowing ? AppColors.surfaceElevated : AppColors.primary)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(vm.isFollowLoading)

            if showsMessageButton, let me = Auth.auth().currentUser?.uid {
                NavigationLink {
                    ChatView(
                        conversationId: ChatApiService.shared.conversationId(for: me, and: userId),
                        peerUserId: userId
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Message")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(AppColors.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                            .fill(AppColors.surfaceElevated)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().tint(AppColors.primary)
            Text("Loading profile…")
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Error State

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 14) {
            Text("Couldn’t load this profile")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.primaryText)
            Text(error)
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await vm.load(userId: userId) }
            }
            .font(AppFonts.subheadline())
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppColors.surfaceElevated)
            .foregroundColor(AppColors.primaryText)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, 32)
    }
}

// MARK: - Report sheet

private struct ReportUserSheet: View {
    let userId: String
    let userName: String

    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportService.Reason?
    @State private var details: String = ""
    @State private var isSending = false
    @State private var sent = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Thanks for letting us know", systemImage: "checkmark.circle.fill")
                                .foregroundColor(AppColors.live)
                            Text("We’ll review \(userName)’s profile. You can also block them so they can’t reach you.")
                                .font(AppFonts.footnote())
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                } else {
                    Section("What’s wrong?") {
                        ForEach(ReportService.Reason.allCases) { option in
                            Button {
                                reason = option
                            } label: {
                                HStack {
                                    Text(option.label)
                                        .foregroundColor(AppColors.primaryText)
                                    Spacer()
                                    if reason == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppColors.primary)
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        TextField("Anything else we should know? (optional)", text: $details, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .melScreenBackground()
            .navigationTitle("Report \(userName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }
                }
                if !sent {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isSending ? "Sending…" : "Send") {
                            Task { await send() }
                        }
                        .disabled(reason == nil || isSending)
                    }
                }
            }
        }
    }

    private func send() async {
        guard let reason else { return }
        isSending = true
        errorMessage = nil
        do {
            try await ReportService.shared.report(userId: userId, reason: reason, details: details)
            sent = true
        } catch {
            errorMessage = "Couldn’t send your report. Please try again."
        }
        isSending = false
    }
}

// MARK: - ViewModel

@MainActor
final class UserProfilePreviewViewModel: ObservableObject {

    @Published var user: AppUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var actionError: String?
    @Published var followerCount: Int?
    @Published var likesReceivedCount: Int?
    @Published var isFollowing: Bool = false
    @Published var isFollowLoading: Bool = false

    private var loadedUserId: String?

    var isOwnProfile: Bool {
        guard let loadedUserId else { return false }
        return Auth.auth().currentUser?.uid == loadedUserId
    }

    func load(userId: String) async {
        // Coming back from a pushed screen re-runs `.task`; don't blank a
        // profile we already have.
        let alreadyLoaded = loadedUserId == userId && user != nil
        loadedUserId = userId

        if !alreadyLoaded {
            isLoading = true
            errorMessage = nil
            user = nil

            do {
                let fetchedUser = try await fetchUser(uid: userId)
                user = fetchedUser
                isLoading = false
            } catch {
                errorMessage = "Check your connection and try again."
                isLoading = false
                return
            }
        }

        // Counts and follow state are cheap; refresh them on every appearance
        // (e.g. after coming back from the followers list).

        async let followerCountFetch = FollowApiService.shared.fetchFollowerCount(of: userId)
        async let likesFetch = LikeApiService.shared.fetchLikesReceivedCount(for: userId)
        async let followingCheck = FollowApiService.shared.isFollowing(userId: userId)

        followerCount = try? await followerCountFetch
        likesReceivedCount = try? await likesFetch
        isFollowing = (try? await followingCheck) ?? false
    }

    func toggleFollow() async {
        guard let loadedUserId, !isOwnProfile else { return }

        isFollowLoading = true
        defer { isFollowLoading = false }

        let wasFollowing = isFollowing
        // Optimistic update
        isFollowing.toggle()
        followerCount = max(0, (followerCount ?? 0) + (wasFollowing ? -1 : 1))

        do {
            if wasFollowing {
                try await FollowApiService.shared.unfollow(userId: loadedUserId)
            } else {
                try await FollowApiService.shared.follow(userId: loadedUserId)
            }
        } catch {
            // Roll back optimistic update
            isFollowing = wasFollowing
            followerCount = max(0, (followerCount ?? 0) + (wasFollowing ? 1 : -1))
            actionError = wasFollowing ? "Couldn’t unfollow. Please try again." : "Couldn’t follow. Please try again."
        }
    }

    /// Blocks the user and closes any chat with them. Returns `true` on success.
    func block() async -> Bool {
        guard let loadedUserId, !isOwnProfile, let me = Auth.auth().currentUser?.uid else { return false }
        do {
            try await BlockService.shared.blockUser(userId: loadedUserId)
            let convoId = ChatApiService.shared.conversationId(for: me, and: loadedUserId)
            try? await ChatApiService.shared.deleteConversation(conversationId: convoId)
            return true
        } catch {
            actionError = "Couldn’t block this person. Please try again."
            return false
        }
    }

    private func fetchUser(uid: String) async throws -> AppUser {
        return try await withCheckedThrowingContinuation { continuation in
            UserApiService.shared.fetchUser(uid: uid) { result in
                continuation.resume(with: result)
            }
        }
    }
}
